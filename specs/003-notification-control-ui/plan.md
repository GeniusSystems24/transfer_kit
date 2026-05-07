# Implementation Plan: Notification Control and UI Design

**Branch**: `main` (working directory) | **Date**: 2026-05-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/003-notification-control-ui/spec.md`

## Summary

Replace the directly-coupled `awesome_notifications` calls in `lib/src/service/background_transfer_service.dart` with a dedicated notification orchestration layer composed of six small components: `TransferNotificationConfig`, `TransferNotificationTemplate`, `TransferNotificationAdapter` (interface), `AwesomeNotificationAdapter` (built-in default), `TransferNotificationPolicy` (decision engine), and `TransferNotificationCoordinator` (lifecycle observer that throttles, deduplicates, groups, and dispatches to the adapter). All notification configuration is exposed through the existing `TransferKitConfig` singleton; notifications default to **disabled (opt-in)**; the system supports Android and iOS only and silently no-ops on other platforms. The actions interface is declared in v1 but implementation is optional. A `FakeNotificationAdapter` enables full branch coverage of the policy and coordinator.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (FVM-pinned, see project root `.fvmrc`)
**Primary Dependencies**: existing — `awesome_notifications` (retained as built-in adapter only), `workmanager`, `shared_preferences`, `get_storage`, `path_provider`, `logger`. No new package dependencies.
**Storage**: existing `GetStorage` (for task state persistence — read-only consumer here). Notification throttle state is process-memory only.
**Testing**: `flutter_test`. New `FakeNotificationAdapter` lives under `test/src/notification/fake/`.
**Target Platform**: Android and iOS (required). macOS, Windows, Linux, Web silently no-op per FR-016 / spec clarification.
**Project Type**: Flutter package (single project, library only — no app, no backend).
**Performance Goals**: Notification throttle default = 1000 ms (FR-004). Coordinator MUST update existing notification records — never create duplicates per task (FR-005). Permission check returns in < 100 ms with no system dialog (SC-007).
**Constraints**: Notification failures MUST NOT block transfers (FR-014). Global `enableNotifications: false` (default) takes precedence over all other flags (FR-015). The package MUST remain compilable and shippable without notifications enabled — i.e. `awesome_notifications` channel registration must not happen at import time.
**Scale/Scope**: ~7 new files under `lib/src/notification/` plus 1 modification to `TransferKitConfig`, 1 refactor to `BackgroundTransferService` to remove inline notification code, and ~4 new test files. Estimated touched LOC: ~600 added, ~120 removed.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
| --- | --- | --- |
| I. Public Package Stability | ⚠ Justified breaking | Notifications change from "on by default" (current `BackgroundTransferService`) to "off by default" (FR-001). This IS a behavioral breaking change for any consumer relying on the current implicit notifications. Migration: a single `TransferKitConfig.init(notificationConfig: TransferNotificationConfig(enabled: true))` call restores notifications. Documented in CHANGELOG and README per Principle XII. |
| II. Correct Transfer Lifecycle | ✅ Pass | No lifecycle state is altered. Note: spec FR-007 lists `retrying` as a notification-relevant state, but `FileTaskState` enum does not contain it. The coordinator treats "retry initiated" as a transition into `running` (the existing semantics) and the policy fires a one-shot retry notification on the `retrying` *event* surfaced by `TaskManagementService.retryTask()`. No change to the enum. |
| III. Single Source of Truth | ✅ Pass | Coordinator subscribes to existing task state stream via `FileTaskRepository`. It never mutates task state. |
| IV. Stream Sharing & Resource Safety | ✅ Pass | Coordinator holds at most one subscription per active task and disposes on terminal states (`completed`, `error`, `cancelled`, `cached`). Throttle timers are per-task and cancelled on terminal state. |
| V. Cache Correctness | ✅ Pass | Not affected. |
| VI. Provider Abstraction Boundary | ✅ Pass | Mirrors the `TransferDriver` pattern. `TransferNotificationAdapter` is the abstraction; `AwesomeNotificationAdapter` and `FakeNotificationAdapter` are concrete implementations. No `awesome_notifications` import allowed outside `awesome_notification_adapter.dart`. |
| VII. Background Transfer Honesty | ✅ Pass with doc | README must clarify that background notification delivery on iOS is subject to OS limits and that the coordinator runs in the same isolate as the transfer driver. |
| VIII. Metadata Extraction Safety | ✅ Pass | Not affected. |
| IX. Error Handling and Logging | ✅ Pass | Notification failures are caught inside the coordinator and logged at `debug` level only. Notification body text is built only from developer-supplied template fields and resolved task identifiers — no URLs, tokens, or signed paths leak by default. |
| X. Performance and Memory Efficiency | ✅ Pass | Throttling enforced per-task at default 1000 ms. Coordinator subscribes once per task; reference-counted disposal. No hot-path full-set rebuilds. |
| XI. Testing Requirements | ✅ Pass | Fake adapter is mandatory and is the canonical test double. Coordinator and policy decision logic require full branch coverage (SC-006). |
| XII. Documentation and Release Discipline | ✅ Pass — required deliverable | README gets a new "Notifications" section with an opt-in example. CHANGELOG documents the behavioral breaking change. Platform limitations (iOS rich notifications, Android channel registration, no-op on desktop/web) documented. |

**One justified deviation** (Principle I): the breaking change from notifications-on-by-default to notifications-off-by-default. Recorded in Complexity Tracking below.

## Project Structure

### Documentation (this feature)

```text
specs/003-notification-control-ui/
├── plan.md                                    # This file
├── research.md                                # Phase 0 output
├── data-model.md                              # Phase 1 output
├── quickstart.md                              # Phase 1 output
├── contracts/
│   └── notification-adapter.md                # Phase 1: public adapter contract
├── checklists/
│   └── requirements.md                        # From /speckit-specify
└── tasks.md                                   # Phase 2 output (/speckit-tasks — NOT created here)
```

### Source Code (TransferKit package)

```text
packages/transfer_kit/
├── lib/
│   ├── transfer_kit.dart                      # Barrel export — add notification public symbols
│   └── src/
│       ├── core/
│       │   └── file_management_config.dart    # MODIFY — add notificationConfig parameter
│       ├── service/
│       │   └── background_transfer_service.dart  # REFACTOR — remove inline awesome_notifications calls; delegate to coordinator
│       └── notification/                      # NEW directory — all new code lives here
│           ├── config/
│           │   ├── transfer_notification_config.dart
│           │   └── transfer_notification_template.dart
│           ├── model/
│           │   ├── transfer_notification_payload.dart
│           │   ├── notification_grouping_mode.dart
│           │   ├── notification_permission_status.dart
│           │   └── transfer_notification_action.dart
│           ├── adapter/
│           │   ├── transfer_notification_adapter.dart        # abstract interface
│           │   └── awesome_notification_adapter.dart         # built-in default impl
│           ├── policy/
│           │   └── transfer_notification_policy.dart
│           └── coordinator/
│               └── transfer_notification_coordinator.dart
└── test/
    └── src/
        └── notification/                      # NEW
            ├── fake/
            │   └── fake_notification_adapter.dart
            ├── policy_test.dart
            ├── coordinator_test.dart
            ├── throttle_test.dart
            └── grouping_test.dart
```

**Structure Decision**: Single library (Flutter package). All new notification code is contained under `lib/src/notification/` to keep the boundary explicit and grep-discoverable. The `awesome_notifications` import is restricted to a single file (`awesome_notification_adapter.dart`) so swapping adapters does not ripple through the package.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
| --- | --- | --- |
| Behavioral breaking change: notifications default `false` instead of current `true` | Spec clarification Q1 / FR-001 mandates opt-in to satisfy library hygiene (libraries should not affect system state without explicit developer consent). The current implicit behavior is the very problem this feature solves. | Keeping notifications on by default would preserve compatibility but violates the entire intent of the feature — every other FR (per-type toggle, per-state toggle, throttling) becomes pointless if the global default opts users in. The breaking change is documented with a one-line migration recipe in CHANGELOG and README. |
| Six new classes for notification orchestration (config, template, adapter, policy, coordinator, payload) | Each class has a single responsibility (mirrors the `TransferDriver` / `TransferCapabilities` pattern already validated in the codebase). Splitting policy from coordinator enables full unit testing of decision logic without time-dependent throttle behavior. | Folding policy into coordinator would couple decision logic to subscription lifecycle, making it impossible to test "would this state transition fire a notification?" as a pure function. |
