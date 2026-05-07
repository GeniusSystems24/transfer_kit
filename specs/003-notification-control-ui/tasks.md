# Tasks: Notification Control and UI Design

**Input**: Design documents from `specs/003-notification-control-ui/`
**Prerequisites**: plan.md ✅ | spec.md ✅ | research.md ✅ | data-model.md ✅ | contracts/ ✅ | quickstart.md ✅

**Tests**: Mandatory per Constitution Principle XI — this feature touches transfer lifecycle and stream subscriptions. All test tasks are required.

**Organization**: Tasks grouped by user story for independent implementation and testing.
**Path convention**: `lib/` and `test/` at package root (`packages/transfer_kit/`).

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no incomplete dependencies)
- **[Story]**: Which user story this task belongs to
- All file paths are relative to `packages/transfer_kit/`

---

## Phase 1: Setup

**Purpose**: Create the directory skeleton. No logic yet — just file structure.

- [X] T001 Create directory `lib/src/notification/config/`, `lib/src/notification/model/`, `lib/src/notification/adapter/`, `lib/src/notification/policy/`, `lib/src/notification/coordinator/`
- [X] T002 Create directory `test/src/notification/fake/`

**Checkpoint**: Directory skeleton exists. All subsequent tasks can target concrete file paths.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: All shared models, enums, and the adapter contract that every user story depends on. No user story work begins until this phase is complete.

**⚠️ CRITICAL**: Phases 3–9 all depend on this phase being complete.

### Enums and small models (all parallelizable)

- [X] T003 [P] Create `NotificationGroupingMode` enum (`perFile`, `batch`, `none`) in `lib/src/notification/model/notification_grouping_mode.dart`
- [X] T004 [P] Create `NotificationPermissionStatus` enum (`granted`, `denied`, `restricted`, `notDetermined`) in `lib/src/notification/model/notification_permission_status.dart`
- [X] T005 [P] Create `NotificationEventKind` enum (`progress`, `terminal`, `retry`) in `lib/src/notification/model/notification_event_kind.dart`
- [X] T006 [P] Create `TransferType` enum (`upload`, `download`) in `lib/src/notification/model/transfer_type.dart`
- [X] T007 [P] Create `TransferNotificationAction` model (fields: `key`, `label`, `iconKey`) in `lib/src/notification/model/transfer_notification_action.dart`

### Core models (sequential — each builds on previous)

- [X] T008 Create `TransferNotificationPayload` immutable model (all fields from data-model.md §4, including `notificationId`, `transferType`, `state`, `progress`, `title`, `body`, `actions`, `timestamp`) in `lib/src/notification/model/transfer_notification_payload.dart` — depends on T005, T006, T007
- [X] T009 Create `TransferNotificationTemplate` with all text fields, `progressText` closure, `groupedTitle` closure, `localization` map, `resolveText` callback, `actions` list, and static factories `defaultUpload()` / `defaultDownload()` in `lib/src/notification/config/transfer_notification_template.dart` — depends on T007, T008
- [X] T010 Create `TransferNotificationAdapter` abstract interface with methods: `checkPermission()`, `requestPermission()`, `showOrUpdateProgress()`, `showCompletion()`, `showError()`, `cancel()`, `cancelGroup()`, `dispose()` per `contracts/notification-adapter.md` in `lib/src/notification/adapter/transfer_notification_adapter.dart` — depends on T004, T008
- [X] T011 Create `TransferNotificationConfig` with all flags, `throttleDuration` (default `1000 ms`), `grouping`, `uploadTemplate`, `downloadTemplate`, `adapter`, `requestPermissionOnInit`; convenience factories `disabled()`, `uploadsOnly()`, `downloadsOnly()`; assert `throttleDuration > Duration.zero` in `lib/src/notification/config/transfer_notification_config.dart` — depends on T003, T009, T010

### Infrastructure (sequential)

- [X] T012 Modify `lib/src/core/file_management_config.dart` — add optional `TransferNotificationConfig? notificationConfig` param to `TransferKitConfig.init()` (default `TransferNotificationConfig.disabled()`), add getter `notificationConfig`, mutator `setNotificationConfig()`, and entry in `toMap()` — depends on T011
- [X] T013 Create `AwesomeNotificationAdapter` in `lib/src/notification/adapter/awesome_notification_adapter.dart` — implement `TransferNotificationAdapter`; lazy channel registration on first `show*` call; platform guard via `defaultTargetPlatform` (no-op + return `notDetermined` on non-Android/iOS); stable notification ID uses `payload.notificationId`; actions field ignored in v1 per R-010 — depends on T010
- [X] T014 Create `FakeNotificationAdapter` test double in `test/src/notification/fake/fake_notification_adapter.dart` — records every method call as `RecordedCall { method, payload, taskOrGroupId, at }`; `permissionStatus` field (default `granted`); `clear()` helper; implements all `TransferNotificationAdapter` methods — depends on T010
- [X] T015 Refactor `lib/src/service/background_transfer_service.dart` — remove all `awesome_notifications` imports and all notification methods (`channel()`, `_createOrUpdateNotification()`, `_createOrUpdateBatchNotification()`, `_getProgressNotificationId()`, `_getSuccessNotificationId()`, `_getFailureNotificationId()`); remove hard-coded channel constants and ID range constants; add private `TransferNotificationCoordinator? _coordinator` field (set during wiring in T019) — depends on T013
- [X] T016 [P] Update `lib/transfer_kit.dart` barrel — export `TransferNotificationConfig`, `TransferNotificationTemplate`, `TransferNotificationAction`, `TransferNotificationPayload`, `TransferNotificationAdapter`, `NotificationGroupingMode`, `NotificationPermissionStatus`, `NotificationEventKind`, `TransferType`; do NOT export coordinator or policy (internal) — depends on T011, T010, T003, T004, T005, T006, T007, T008, T009

**Checkpoint**: Foundation complete. All models, enums, adapter interface, fake adapter, and config extension exist. User story phases may now proceed.

---

## Phase 3: User Story 1 — Disable All Notifications (Priority: P1) 🎯 MVP

**Goal**: TransferKit emits zero notifications by default (opt-in). `enableNotifications: false` (the default) suppresses everything regardless of other flags.

**Independent Test**: Initialize with no `notificationConfig` (or `enabled: false`), run an upload through completion and an error, verify `FakeNotificationAdapter.recordedCalls` is empty.

### Implementation

- [X] T017 [US1] Create `TransferNotificationPolicy` with `shouldNotify({transferType, state, kind})` pure function — for now implement only the global `enabled == false → return false` short-circuit; all other cases return `true` as placeholder; dartdoc covers the full decision matrix from data-model.md §8 in `lib/src/notification/policy/transfer_notification_policy.dart` — depends on T011, T005, T006
- [X] T018 [US1] Create `TransferNotificationCoordinator` skeleton in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — constructor takes `config`, `adapter`, `repository`; `start()` begins observing `FileTaskRepository` task stream (subscribe per task lazily); on each state event: check `policy.shouldNotify(...)` → if true call adapter method matching state; `dispose()` cancels all subscriptions and calls `adapter.dispose()`; wrap every adapter call in `try/catch`, log debug on failure (FR-014) — depends on T013, T017, T014
- [X] T019 [US1] Wire coordinator into `TransferKitConfig.init()` — after config is stored, if `notificationConfig.enabled == true` instantiate `AwesomeNotificationAdapter` (or `notificationConfig.adapter` if set) and `TransferNotificationCoordinator`, call `coordinator.start()`; if `enabled == false` coordinator is never created; expose `TransferKit.instance.notificationCoordinator` internal accessor for test wiring in `lib/src/transfer_kit.dart` — depends on T018, T012

### Tests (mandatory)

- [X] T020 [P] [US1] Test — no-op default: initialize with no `notificationConfig`, run upload + download to completion → `FakeNotificationAdapter.recordedCalls` is empty in `test/src/notification/coordinator_test.dart` — depends on T014, T019
- [X] T021 [P] [US1] Test — explicit `enabled: false`: initialize with `TransferNotificationConfig(enabled: false)` and fake adapter, emit progress + completion + error events → zero recorded calls in `test/src/notification/coordinator_test.dart` — depends on T014, T019
- [X] T022 [P] [US1] Test — global precedence (FR-015): `enabled: false` with `uploadEnabled: true`, `showCompletion: true` → still zero calls; assert policy returns false unconditionally in `test/src/notification/policy_test.dart` — depends on T017, T014

**Checkpoint**: US1 done. Enabling notifications with `enabled: true` and a fake adapter routes events; disabled (default) routes nothing. MVP is shippable.

---

## Phase 4: User Story 2 — Per-Type Notification Toggle (Priority: P1)

**Goal**: Upload and download notifications can be independently enabled or disabled.

**Independent Test**: Set `uploadEnabled: false`, `downloadEnabled: true`, `enabled: true`; emit upload-completion and download-completion events through a fake adapter; only download calls appear in `recordedCalls`.

### Implementation

- [X] T023 [US2] Extend `TransferNotificationPolicy.shouldNotify()` — after the global `enabled` gate add: if `transferType == upload && !config.uploadEnabled → return false`; if `transferType == download && !config.downloadEnabled → return false` in `lib/src/notification/policy/transfer_notification_policy.dart` — depends on T017

### Tests (mandatory)

- [X] T024 [P] [US2] Test — `uploadEnabled: false`, `downloadEnabled: true`: emit upload-completion → no call; emit download-completion → one `showCompletion` call in `test/src/notification/policy_test.dart` — depends on T023, T014
- [X] T025 [P] [US2] Test — `uploadEnabled: true`, `downloadEnabled: false`: emit download-error → no call; emit upload-error → one `showError` call in `test/src/notification/policy_test.dart` — depends on T023, T014
- [X] T026 [P] [US2] Test — both disabled with `enabled: true`: neither upload nor download produces calls in `test/src/notification/policy_test.dart` — depends on T023, T014

**Checkpoint**: US2 done. Per-type control verified independently.

---

## Phase 5: User Story 3 — Selective Lifecycle Notifications (Priority: P2)

**Goal**: Developers can show only the lifecycle states they care about (e.g. completion + error only, no progress).

**Independent Test**: Set only `showCompletion: true`, `showErrors: true`, all others false; run a task through `waiting → running → paused → running → completed` sequence; verify only one `showCompletion` call recorded.

### Implementation

- [X] T027 [US3] Extend `TransferNotificationPolicy.shouldNotify()` — add per-state gate after per-type gate: `running/progress → config.showProgress`; `completed/terminal → config.showCompletion`; `error/terminal → config.showErrors`; `cancelled/terminal → config.showCancelled`; `paused/progress → config.showPaused`; `retry → config.showRetry`; `waiting → false` (never notifies); `cached → false` (v1 silent per R-009) in `lib/src/notification/policy/transfer_notification_policy.dart` — depends on T023

### Tests (mandatory)

- [X] T028 [P] [US3] Test — progress suppressed: `showProgress: false`, `showCompletion: true`; emit 5 progress events then completion → zero progress calls, one completion call in `test/src/notification/policy_test.dart` — depends on T027, T014
- [X] T029 [P] [US3] Test — `showCancelled: false` (default): emit cancelled event → no call; `showCancelled: true`: emit cancelled → one `showCompletion` call in `test/src/notification/policy_test.dart` — depends on T027, T014
- [X] T030 [P] [US3] Test — waiting state never notifies regardless of any flag in `test/src/notification/policy_test.dart` — depends on T027
- [X] T031 [P] [US3] Test — cached state never notifies in v1 regardless of flags in `test/src/notification/policy_test.dart` — depends on T027
- [X] T032 [P] [US3] Test — `showPaused: true`: paused transition produces a `showOrUpdateProgress` call with paused text; `showPaused: false`: no call in `test/src/notification/policy_test.dart` — depends on T027, T014

**Checkpoint**: US3 done. Full lifecycle decision matrix verified with pure-function tests.

---

## Phase 6: User Story 4 — Throttled Progress Notifications (Priority: P2)

**Goal**: Progress events update a single persistent notification per task (no duplicates); updates are throttled to at most one per `throttleDuration`; terminal events bypass the throttle immediately.

**Independent Test**: Using `fake_async`, configure `throttleDuration: 2s`, emit 20 progress events over 10 simulated seconds; verify `recordedCalls` contains ≤ 5 `showOrUpdateProgress` entries for the same task ID with all using the same `notificationId`.

### Implementation

- [X] T033 [US4] Add stable notification ID derivation to coordinator — compute `kNotificationIdRangeStart + (taskId.hashCode.abs() % kNotificationIdRangeSize)` once per task on first event; store in `_TaskSubscription`; pass as `payload.notificationId`; constants `kNotificationIdRangeStart = 10000`, `kNotificationIdRangeSize = 29999` in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — depends on T018
- [X] T034 [US4] Implement per-task throttle gate in coordinator — `_TaskSubscription` holds `Stopwatch _throttle` and `Timer? _trailingTimer`; on progress event: if stopwatch not started or elapsed ≥ throttleDuration → fire immediately and restart stopwatch; else store latest payload and schedule trailing timer for remaining window; on trailing timer fire → emit stored payload, reset stopwatch in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — depends on T033
- [X] T035 [US4] Ensure terminal states bypass throttle — when state ∈ `{completed, error, cancelled, cached}`: cancel pending trailing timer, emit terminal notification immediately, then dispose subscription in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — depends on T034

### Tests (mandatory, use `fake_async`)

- [X] T036 [P] [US4] Test — dedup: 10 rapid progress events for same task → all use same `notificationId`; no duplicate tray entries in `test/src/notification/throttle_test.dart` — depends on T014, T033
- [X] T037 [P] [US4] Test — throttle window: `throttleDuration: 2s`, 10 events in 10s → at most 5 `showOrUpdateProgress` calls (one per window) in `test/src/notification/throttle_test.dart` — depends on T014, T034
- [X] T038 [P] [US4] Test — trailing edge: last progress payload is emitted at end of throttle window even when no new event arrives in `test/src/notification/throttle_test.dart` — depends on T034
- [X] T039 [P] [US4] Test — terminal bypass: completion fires immediately without waiting for throttle window; pending trailing timer cancelled in `test/src/notification/throttle_test.dart` — depends on T035
- [X] T040 [P] [US4] Test — subscription cleanup: after terminal event, no further adapter calls for that task even if spurious events arrive in `test/src/notification/coordinator_test.dart` — depends on T035

**Checkpoint**: US4 done. No notification spam; dedup and throttle verified with controlled time.

---

## Phase 7: User Story 5 — Customizable Notification Design (Priority: P2)

**Goal**: Developers supply custom text, icons, and localization for upload and download notifications independently; partial templates fall back to defaults.

**Independent Test**: Provide upload template with `title: "Sending…"`, download template with `successText: "Got it!"`. Run both transfer types; verify `recordedCalls` for upload show `title == "Sending…"`, and download completion shows `body == "Got it!"`.

### Implementation

- [X] T041 [US5] Wire template resolution into coordinator — on each notification event select `config.uploadTemplate` or `config.downloadTemplate` based on `payload.transferType`; resolve title/body/progressText/successText by calling `template.resolveText(key, payload)` if set, else fall back to the matching string field, else fall back to factory default; populate `payload.title` and `payload.body` before passing to adapter in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — depends on T034, T009
- [X] T042 [US5] Implement `resolveText` fallback chain in `TransferNotificationTemplate` — helper method `String resolve(String key, TransferNotificationPayload p)`: if `resolveText != null` call it; else look up `localization[key]`; else return string field for key; else return factory default in `lib/src/notification/config/transfer_notification_template.dart` — depends on T009

### Tests (mandatory)

- [X] T043 [P] [US5] Test — custom upload template: `title: "Sending…"` → all upload notifications carry `payload.title == "Sending…"` in `test/src/notification/coordinator_test.dart` — depends on T041, T014
- [X] T044 [P] [US5] Test — custom download success: `successText: "Got it!"` → download completion payload `body == "Got it!"` in `test/src/notification/coordinator_test.dart` — depends on T041, T014
- [X] T045 [P] [US5] Test — `resolveText` override supersedes string fields in `test/src/notification/coordinator_test.dart` — depends on T042, T014
- [X] T046 [P] [US5] Test — partial template: only `title` overridden, `successText` falls back to default factory string in `test/src/notification/coordinator_test.dart` — depends on T042, T014
- [X] T047 [P] [US5] Test — localization map: provide `localization: {"progress": "جارٍ الرفع…"}` and `resolveText` that looks up the map; emit progress event → Arabic string appears in payload in `test/src/notification/coordinator_test.dart` — depends on T042, T014

**Checkpoint**: US5 done. Custom templates and localization verified independently.

---

## Phase 8: User Story 6 — Batch Transfer Grouped Notification (Priority: P3)

**Goal**: Multi-file transfers with `notificationGrouping: batch` produce exactly one grouped notification summarising overall progress, not one per file.

**Independent Test**: Initiate 5 uploads sharing the same `groupId` with `grouping: batch`; after all progress events, verify `recordedCalls` contains exactly one `showOrUpdateProgress` record per throttle window (not 5), all carrying the group `notificationId` derived from the `groupId`.

### Implementation

- [X] T048 [US6] Implement `_GroupAggregator` internal class in coordinator — tracks `Map<taskId, double progress>` per group; recomputes `totalProgress = sum / count` on each update; exposes `groupNotificationId` (hash of groupId in same range as per-task IDs) in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — depends on T034
- [X] T049 [US6] Switch dispatch logic in coordinator based on `config.grouping` — `perFile`: existing per-task dispatch; `batch`: suppress per-task notifications, update `_GroupAggregator` instead, dispatch one `showOrUpdateProgress` with group-level payload when aggregator updates; `none`: suppress all notifications (policy still runs for logging but adapter never called) in `lib/src/notification/coordinator/transfer_notification_coordinator.dart` — depends on T048

### Tests (mandatory)

- [X] T050 [P] [US6] Test — `batch` mode: 5 tasks same `groupId`, 3 progress events each → all `showOrUpdateProgress` calls carry the group `notificationId`, not individual task IDs in `test/src/notification/grouping_test.dart` — depends on T049, T014
- [X] T051 [P] [US6] Test — `perFile` mode: 5 tasks → 5 distinct notification IDs used, one per task in `test/src/notification/grouping_test.dart` — depends on T049, T014
- [X] T052 [P] [US6] Test — `none` mode: 5 tasks emit progress + completion → zero adapter calls in `test/src/notification/grouping_test.dart` — depends on T049, T014
- [X] T053 [P] [US6] Test — batch group progress updates as tasks complete: group payload `progress` increases monotonically in `test/src/notification/grouping_test.dart` — depends on T048, T014

**Checkpoint**: US6 done. Batch grouping modes verified independently.

---

## Phase 9: User Story 7 — Notification Permission Guidance (Priority: P3)

**Goal**: Developers can query and request notification permission at a time of their choosing; TransferKit never auto-requests permission unless configured; unsupported platforms return `notDetermined`.

**Independent Test**: Using `FakeNotificationAdapter` with `permissionStatus = denied`, call `TransferKit.instance.checkNotificationPermission()` → returns `denied` in under 100 ms with no system dialog; call `requestNotificationPermission()` → returns `denied` via fake.

### Implementation

- [X] T054 [US7] Add `checkNotificationPermission()` and `requestNotificationPermission()` public methods to `TransferKit` singleton — delegates to `coordinator.adapter.checkPermission()` and `.requestPermission()` respectively; if coordinator not initialized (notifications disabled) return `notDetermined` in `lib/src/transfer_kit.dart` — depends on T019, T013
- [X] T055 [US7] Implement `AwesomeNotificationAdapter.checkPermission()` — call `AwesomeNotifications().isNotificationAllowed()` on Android+iOS, return `notDetermined` on other platforms; map `bool` → `granted`/`denied`; ensure no dialog is triggered in `lib/src/notification/adapter/awesome_notification_adapter.dart` — depends on T013
- [X] T056 [US7] Implement `AwesomeNotificationAdapter.requestPermission()` — call `AwesomeNotifications().requestPermissionToSendNotifications()` on Android+iOS, return `notDetermined` on other platforms in `lib/src/notification/adapter/awesome_notification_adapter.dart` — depends on T055
- [X] T057 [US7] Verify FR-013 — add assertion test that `AwesomeNotificationAdapter` constructor does NOT call `requestPermission()` and that `TransferKitConfig.init()` with `requestPermissionOnInit: false` (default) never triggers a permission dialog; document the `requestPermissionOnInit: true` path in `lib/src/notification/adapter/awesome_notification_adapter.dart` — depends on T056

### Tests (mandatory)

- [X] T058 [P] [US7] Test — `FakeNotificationAdapter.permissionStatus = denied`, call `checkNotificationPermission()` → `denied` returned, zero `show*` calls in `test/src/notification/coordinator_test.dart` — depends on T054, T014
- [X] T059 [P] [US7] Test — permission not auto-requested: initialize with `requestPermissionOnInit: false` → `requestPermission()` never called on fake adapter in `test/src/notification/coordinator_test.dart` — depends on T057, T014
- [X] T060 [P] [US7] Test — unsupported platform: simulate non-Android/iOS `defaultTargetPlatform` in `AwesomeNotificationAdapter`; `checkPermission()` returns `notDetermined` without touching `AwesomeNotifications` API in `test/src/notification/coordinator_test.dart` — depends on T055

**Checkpoint**: US7 done. All 7 user stories independently complete.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates, documentation, and resilience verification.

- [X] T061 [P] Update `README.md` — add "Notifications" section with opt-in example, per-type toggle, lifecycle toggle, throttle config, custom template, grouped batch, permission API, platform support table, migration note from old implicit behavior; drawn from `quickstart.md` — no story dependency
- [X] T062 [P] Update `CHANGELOG.md` — add entry under new version heading: breaking change (notifications off by default), migration recipe (`enabled: true`), new APIs (`TransferNotificationConfig`, `TransferNotificationAdapter`, `TransferNotificationTemplate`, permission helpers), removed (inline `awesome_notifications` calls from `BackgroundTransferService`)
- [X] T063 [P] Add `FakeNotificationAdapter` unit tests — verify `recordedCalls` empty initially; verify `clear()` resets state; verify each method records correct `method` name and payload in `test/src/notification/fake/fake_notification_adapter_test.dart` — depends on T014
- [X] T064 Run `dart format .` on all new and modified files and fix any formatting issues — depends on T060, T056, T057
- [X] T065 Run `flutter analyze` and resolve any new issues introduced by this feature — depends on T064
- [X] T066 Run `flutter test` and confirm all new tests pass and zero regressions in existing tests — depends on T065
- [X] T067 [P] Resilience test — inject a `FakeNotificationAdapter` that throws on every call; run a complete upload through completion; verify the upload `FileTask` reaches `completed` state and `FakeTransferDriver` records the expected events — confirms FR-014 (notification failure must not block transfer) in `test/src/notification/coordinator_test.dart` — depends on T035
- [X] T068 [P] Verify SC-007 — `FakeNotificationAdapter.checkPermission()` resolves synchronously; assert call completes in under 100 ms in a real-time test in `test/src/notification/coordinator_test.dart` — depends on T058

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  └── Phase 2 (Foundational) — BLOCKS all user story phases
        ├── Phase 3 (US1 — P1 MVP)
        ├── Phase 4 (US2 — P1)      ← can start in parallel with Phase 3 once Phase 2 done
        ├── Phase 5 (US3 — P2)      ← depends on Phase 4 (policy chain)
        ├── Phase 6 (US4 — P2)      ← depends on Phase 3 coordinator skeleton
        ├── Phase 7 (US5 — P2)      ← depends on Phase 6 coordinator wiring
        ├── Phase 8 (US6 — P3)      ← depends on Phase 6 coordinator wiring
        └── Phase 9 (US7 — P3)      ← depends on Phase 3 wiring
              └── Phase 10 (Polish) — all user stories complete
```

### User Story Internal Dependencies

| Story | Depends On | Can Parallel With |
| --- | --- | --- |
| US1 (T017–T022) | Phase 2 complete | US2 (different policy method) |
| US2 (T023–T026) | T017 (policy base) | US1 tests, US7 |
| US3 (T027–T032) | T023 (per-type gate) | US4, US5, US6, US7 |
| US4 (T033–T040) | T018 (coordinator) | US3, US5 |
| US5 (T041–T047) | T034 (coordinator wiring) | US3, US4 tests |
| US6 (T048–T053) | T034 (coordinator wiring) | US5 |
| US7 (T054–T060) | T019 (wiring) | US3, US5, US6 |

### Within Each Phase

- All `[P]`-tagged tasks within the same phase may run concurrently.
- Models → services → integration ordering is respected by task IDs.
- Tests (T020–T022, etc.) MUST be written and verified to fail before the corresponding implementation task is committed (TDD; per Principle XI).

---

## Parallel Execution Examples

### Phase 2 — Foundational

```
Parallel batch A (T003–T007): all enums and action model
  T003 NotificationGroupingMode
  T004 NotificationPermissionStatus
  T005 NotificationEventKind
  T006 TransferType
  T007 TransferNotificationAction

Then sequentially: T008 → T009 → T010 → T011 → T012

Parallel batch B (once T010 done):
  T013 AwesomeNotificationAdapter
  T014 FakeNotificationAdapter
  T016 Barrel exports
```

### Phase 3 — US1 (MVP)

```
T017 (policy) → T018 (coordinator) → T019 (wiring)

Parallel tests once wiring complete:
  T020 No-op default
  T021 Explicit disabled
  T022 Global precedence
```

### Phase 5 — US3

```
T027 (policy lifecycle gate)

Parallel policy tests:
  T028 Progress suppressed
  T029 Cancelled config
  T030 Waiting never notifies
  T031 Cached never notifies
  T032 Paused config
```

---

## Implementation Strategy

### MVP First — US1 Only (Phases 1–3)

1. Phase 1: Create directories.
2. Phase 2: Build all foundational types. Run `flutter analyze` at checkpoint.
3. Phase 3: Policy (enabled gate) + coordinator (subscribe/dispatch) + wiring + tests.
4. **STOP AND VALIDATE**: `flutter test test/src/notification/` passes. Confirm no notification appears on a real device with default config. Confirm notifications appear with `enabled: true`.
5. Ship if needed.

### Incremental Delivery

- After US1 (P1): safe upgrade path — existing consumers unaffected, opt-in works.
- After US2 (P1): per-type control verified.
- After US3–US5 (P2): lifecycle control, throttle, custom templates.
- After US6–US7 (P3): batch grouping, permission API.
- After Phase 10: README + CHANGELOG complete, all quality gates green.

### Parallel Team Strategy

With two developers after Phase 2 completes:

- **Dev A**: US1 (T017–T022) → US4 (T033–T040) → US5 (T041–T047)
- **Dev B**: US2 (T023–T026) → US3 (T027–T032) → US6 (T048–T053) → US7 (T054–T060)

---

## Definition of Done

- [X] `dart format .` passes
- [X] `flutter analyze` passes with zero new issues
- [X] `flutter test` passes — all 68 tasks complete, all new tests green, zero regressions
- [X] `FakeNotificationAdapter` used as sole test double (no `awesome_notifications` in tests)
- [X] `awesome_notifications` import exists in exactly one file: `awesome_notification_adapter.dart`
- [X] `BackgroundTransferService` contains zero `awesome_notifications` references
- [X] `README.md` has Notifications section with migration note
- [X] `CHANGELOG.md` documents the breaking change
- [X] All 7 user stories verifiable via quickstart.md walkthroughs

---

## Notes

- `[P]` tasks touch different files and have no incomplete dependencies — safe to parallelize.
- `[Story]` labels trace each task back to a specific acceptance scenario in `spec.md`.
- Each story phase ends with a named checkpoint that is independently testable.
- Avoid merging unrelated refactors into these tasks (Principle XI: smallest safe change).
- Commit after each logical group or at each checkpoint.
- The coordinator never mutates `FileTask.state` — it only reads (Principle III).
