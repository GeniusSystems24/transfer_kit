# Phase 0 Research: Notification Control and UI Design

**Date**: 2026-05-07
**Feature**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)

This document resolves all open questions before design. Spec clarifications (Q1–Q5) handled the user-facing decisions; this document handles the implementation-facing decisions discovered during the codebase audit.

---

## R-001: Existing notification implementation in `BackgroundTransferService`

**Decision**: The current notification logic in `lib/src/service/background_transfer_service.dart` (lines 28–250) will be **fully removed** from that file. The service will only emit lifecycle events; the new `TransferNotificationCoordinator` consumes those events and renders notifications.

**Findings**:

- Direct `awesome_notifications` import at line 6.
- Hard-coded notification channel constants (`notificationChannelKey`, channel name, color, vibration, sound) at lines 28–47.
- Hard-coded notification ID ranges (`_progressNotificationIdStart = 10000`, `_successNotificationIdStart = 20000`, `_failureNotificationIdStart = 30000`) at lines 50–55.
- `_createOrUpdateNotification()` (lines 106–205) renders error / success / progress layouts directly with `NotificationLayout.Default` and `NotificationLayout.ProgressBar`.
- `_createOrUpdateBatchNotification()` invoked at line 62 and during progress at line 250.
- `file_task_controller.dart:286` exposes `myNotificationTapCallback(Task task, NotificationType notificationType)` — preserved for adapter callbacks.

**Rationale**: The current code violates Principle VI (provider abstraction boundary) by hard-coupling `BackgroundTransferService` to one notification SDK. Removing it satisfies FR-010 and the breaking change is justified in plan.md.

**Alternatives considered**:

- *Keep existing code as-is and layer adapter on top* — rejected: leaves dual code paths and duplicate notification IDs.
- *Mark `BackgroundTransferService` as deprecated and add a parallel notification service* — rejected: violates Principle X (single source of truth for notification dispatch) and confuses the public API.

---

## R-002: Task lifecycle event source for the coordinator

**Decision**: The coordinator subscribes to per-task state streams via `FileTaskRepository`. State transitions are observed by polling the existing `taskStream(taskId)` (or equivalent watch method) and computing transitions from previous state to current state.

**Findings**:

- `FileTaskState` enum lives in `lib/src/model/file_task.dart:83–106`; values: `waiting`, `running`, `paused`, `completed`, `cached`, `cancelled`, `error`.
- The enum does **not** include `retrying`. State mutations all happen through `TaskManagementService` (see `task_management_service.dart` lines 207–255).
- `retryTask()` (line 255) sets `task.state = FileTaskState.running` directly — there is no observable "retrying" event today.

**Rationale**: Adding `retrying` to `FileTaskState` is a public-API breaking change (Principle I) outside the scope of this feature. Instead, the coordinator exposes a separate event channel (`TaskManagementService.notifyRetry(taskId)`) called from `retryTask()` immediately before the state mutation. Custom adapters can observe this side channel; the built-in adapter can render a transient retry notification.

**Alternatives considered**:

- *Add `retrying` to `FileTaskState`* — rejected: breaking change to widely-consumed enum.
- *Infer retry from a paused→running transition* — rejected: ambiguous; resume also produces this transition.

---

## R-003: Throttle implementation strategy

**Decision**: Per-task `Stopwatch`-based gate combined with a single trailing-edge `Timer`. On each progress event:

1. If no notification has fired for this task yet → fire immediately and start the stopwatch.
2. If `stopwatch.elapsed < throttleDuration` → store the latest payload and schedule a trailing timer for the remaining window.
3. When the trailing timer fires → emit the most recent stored payload, reset stopwatch.
4. Terminal state events (`completed`, `error`, `cancelled`) bypass throttling and cancel any pending trailing timer.

**Rationale**: Stopwatch is monotonic (immune to wall-clock changes); trailing-edge timer guarantees the user sees the final progress value of any quiet window. Single timer per task keeps memory small.

**Alternatives considered**:

- *RxDart `throttleTime`* — rejected: would add a new dependency for one operator.
- *Periodic global timer* — rejected: O(n) wake-ups per tick across all tasks, wasteful.
- *Leading-edge only* — rejected: final progress value before completion may be lost.

---

## R-004: Notification ID strategy for duplicate prevention

**Decision**: A stable per-task notification ID derived from a deterministic hash of the task ID, mapped into the existing range `[10000, 39999)` to avoid collisions with any existing notification IDs in consumer apps. The adapter computes this once per task and reuses it for show + update + cancel.

```dart
int _notificationIdFor(String taskId) =>
    10000 + (taskId.hashCode.abs() % 29999);
```

**Rationale**: Mirrors the existing range from `BackgroundTransferService` (preserves notification-tray identity through the migration) but consolidates progress / success / failure into one ID per task — so an in-flight progress notification updates seamlessly to a completion notification rather than producing two entries (FR-005, SC-002).

**Alternatives considered**:

- *Separate IDs per state (current behavior)* — rejected: produces duplicate entries in the tray and violates FR-005.
- *Random UUID per task* — rejected: not deterministic, breaks update + cancel by ID.

---

## R-005: Permission-check API on Android vs iOS

**Decision**: The adapter exposes `Future<NotificationPermissionStatus> checkPermission()` and `Future<NotificationPermissionStatus> requestPermission()`. The built-in `AwesomeNotificationAdapter` delegates to:

- **Android**: `AwesomeNotifications().isNotificationAllowed()` for check; `AwesomeNotifications().requestPermissionToSendNotifications()` for request. Maps `bool` → `granted` / `denied`.
- **iOS**: same APIs (awesome_notifications wraps `UNUserNotificationCenter.requestAuthorization`). Maps to `granted` / `denied`. The library does not expose `restricted` distinctly — when the platform reports it, returns `denied` plus logs at `info` level.

**Rationale**: FR-013 forbids automatic permission requests. `checkPermission()` MUST be safe to call at any time and MUST NOT trigger a system dialog (SC-007: < 100 ms). `awesome_notifications`'s `isNotificationAllowed()` is a pure query that satisfies both constraints.

**Alternatives considered**:

- *`permission_handler` package* — rejected: adds a new dependency duplicating capabilities already present in `awesome_notifications`.

---

## R-006: Built-in adapter behavior on unsupported platforms

**Decision**: `AwesomeNotificationAdapter` checks `Platform.isAndroid || Platform.isIOS` (via `defaultTargetPlatform` to remain test-isolate-safe). On any other platform every method returns immediately with no error. `checkPermission()` and `requestPermission()` return `notDetermined`.

**Rationale**: FR-016 / spec clarification Q3. Silent no-op prevents crashes on macOS/Windows/Linux/Web during shared codebases. `defaultTargetPlatform` is preferred over `dart:io`'s `Platform` because it works in tests without `IOOverrides`.

**Alternatives considered**:

- *Throw `UnsupportedPlatformException`* — rejected: spec explicitly requires silent no-op.
- *Conditional import with platform-specific implementations* — rejected: over-engineered for v1; can be added later if other adapters need it.

---

## R-007: Notification template defaults and localization

**Decision**: `TransferNotificationTemplate` carries a `Map<String, String>?` for localization plus a `String Function(BuildContext?, TransferNotificationPayload)? resolveText` callback. When the callback is `null`, the template falls back to plain string fields. Default English strings are baked into the static `TransferNotificationTemplate.defaultUpload()` and `defaultDownload()` factories.

**Rationale**: FR-009 requires localization support without TransferKit shipping translations. A callback gives the developer full control (they can route to `intl` or any localization system). The static defaults guarantee out-of-the-box rendering when the developer enables notifications without supplying a custom template.

**Alternatives considered**:

- *Require an injected `Locale`* — rejected: forces TransferKit to know about Flutter's localization system, leaks abstraction.
- *Map keyed by locale only* — rejected: too rigid; cannot express ICU plurals or developer custom logic.

---

## R-008: Coordinator subscription lifecycle and reference counting

**Decision**: `TransferNotificationCoordinator` maintains `Map<String, _TaskSubscription>` keyed by task ID. A subscription is created lazily on first observed state event for a task and is disposed when:

1. A terminal state is observed (`completed`, `error`, `cancelled`, `cached`), OR
2. The task is removed from the repository (observed via the existing remove event), OR
3. `coordinator.dispose()` is called (test teardown / package shutdown).

After dispose, the throttle timer is cancelled and the notification ID is dismissed via `adapter.cancel(taskId)` only if the global config requires it (e.g., progress notifications cancel on completion if `showCompletionNotifications: false`).

**Rationale**: Aligns with Principle IV (stream sharing & resource safety). Lazy creation avoids pre-allocating subscriptions for tasks that never run. Idempotent disposal protects against double-dispose during cleanup.

**Alternatives considered**:

- *Single global stream subscription* — rejected: forces O(n) filtering per event and complicates per-task throttle state.
- *Eager subscription at task creation* — rejected: wastes resources if many tasks are queued and never started.

---

## R-009: Batch grouping data flow

**Decision**: Group notifications use the existing `groupId` already tracked by `BackgroundTaskRepository` and `MultiUploadFileTask` / `MultiDownloadFileTask` models. The coordinator maintains `Map<String, _GroupAggregator>` and recomputes group progress as `sum(taskProgress) / taskCount`. When `notificationGrouping == NotificationGroupingMode.batch`, individual task notifications are suppressed and only the group notification is rendered.

**Rationale**: Reuses existing batch-tracking infrastructure (no new repository state). FR-006 satisfied by switching aggregation behavior based on grouping mode. SC-003 satisfied because exactly one notification ID is allocated per group.

**Alternatives considered**:

- *New batch-state repository* — rejected: duplicates `BackgroundTaskRepository`.
- *Computing aggregates inside the adapter* — rejected: leaks business logic into the adapter and complicates testing.

---

## R-010: Action declaration without v1 implementation

**Decision**: `TransferNotificationTemplate.actions` is a `List<TransferNotificationAction>?`. Each action carries a key (`pause` / `resume` / `cancel` / `retry` / arbitrary developer key), a localized label, and an optional callback ID for the adapter. The built-in `AwesomeNotificationAdapter` ignores this field. Custom adapters MAY render the actions; if they do, they invoke `TransferKit.handleNotificationAction(actionKey, taskId)` which routes to the existing `TaskManagementService`.

**Rationale**: Spec clarification Q5. Declares the interface so v2 implementations are non-breaking; keeps v1 scope small.

**Alternatives considered**:

- *Omit the field entirely until v2* — rejected: would force a breaking template change in v2.
- *Implement actions in the built-in adapter* — rejected: explicitly out of scope per Q5; would expand the surface area significantly.

---

## R-011: TransferKitConfig integration shape

**Decision**: Add a single new optional named parameter to `TransferKitConfig.init()`:

```dart
TransferKitConfig.init({
  // ... existing parameters ...
  TransferNotificationConfig? notificationConfig,
});
```

Default value (when omitted) is `TransferNotificationConfig.disabled()` — equivalent to `TransferNotificationConfig(enabled: false)`. This is the opt-in default per FR-001. Add corresponding `instance.notificationConfig` getter and `setNotificationConfig(...)` runtime mutator (matches existing pattern of `setLoggingEnabled`, `setCacheEnabled`).

**Rationale**: One additive parameter preserves the existing `init()` signature (Principle I — no rename, no removal). Runtime mutator allows host apps to toggle notification behavior without restarting (e.g., user disables notifications mid-session).

**Alternatives considered**:

- *Flatten notification flags as individual `init()` parameters* — rejected: would balloon the parameter list (12+ new params); poor ergonomics.
- *Singleton `TransferNotificationConfig.instance`* — rejected: creates a parallel singleton outside `TransferKitConfig`, fragmenting the configuration story.

---

## R-012: Test strategy

**Decision**: Three test files cover distinct concerns:

1. `policy_test.dart` — pure-function tests of `TransferNotificationPolicy.shouldNotify(state, transferType, config)`. No timers, no async, no fakes. Covers all 8 lifecycle states × 2 transfer types × all toggle combinations (~64 cases trimmed to representative subsets).
2. `coordinator_test.dart` — uses `FakeNotificationAdapter` and `fake_async` to control timer-based throttle. Verifies subscription lifecycle, dedup by ID, terminal-state cleanup.
3. `throttle_test.dart` — focused on the throttle gate edge cases (immediate first event, trailing edge, terminal-state bypass).
4. `grouping_test.dart` — verifies `perFile` / `batch` / `none` modes with multiple concurrent tasks.

`FakeNotificationAdapter` records every `showOrUpdate / showCompletion / showError / cancel` call with timestamp and full payload, exposing `recordedCalls` for assertions.

**Rationale**: Splitting policy from coordinator (per plan.md complexity tracking) enables fast pure-function tests for the largest decision surface and isolates the slow timer-based tests to one file.

**Alternatives considered**:

- *Single mega-test file* — rejected: hard to navigate, slow feedback loop.
- *Use `mocktail` for the adapter* — rejected: a hand-written fake is more explicit and aligns with the existing `FakeTransferDriver` pattern (constitution Principle VI).

---

## Summary of resolved unknowns

| ID | Topic | Resolution |
| --- | --- | --- |
| R-001 | Existing notification code | Remove inline `awesome_notifications` calls from `BackgroundTransferService` |
| R-002 | Lifecycle event source | Subscribe to per-task streams; route retry events through a side channel |
| R-003 | Throttle algorithm | Stopwatch + trailing-edge Timer per task |
| R-004 | Notification ID | Stable hash-derived ID per task in range `[10000, 39999)` |
| R-005 | Permission API | `awesome_notifications` `isNotificationAllowed` / `requestPermissionToSendNotifications` |
| R-006 | Unsupported platforms | Silent no-op via `defaultTargetPlatform` check |
| R-007 | Localization | `Map<String, String>` + optional resolve callback in template |
| R-008 | Subscription lifecycle | Lazy per-task subscription, disposed on terminal state |
| R-009 | Batch grouping | Reuse existing `groupId`; aggregate in coordinator |
| R-010 | Actions in v1 | Declared in template; built-in adapter ignores |
| R-011 | Config integration | One optional `notificationConfig` parameter on `TransferKitConfig.init()` |
| R-012 | Test strategy | Policy, coordinator, throttle, grouping — all use `FakeNotificationAdapter` |

All NEEDS CLARIFICATION items resolved. Proceed to Phase 1.
