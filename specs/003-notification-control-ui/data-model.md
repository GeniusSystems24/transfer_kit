# Phase 1 Data Model: Notification Control and UI Design

**Date**: 2026-05-07
**Feature**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)
**Research**: [research.md](./research.md)

This document defines the data structures, enums, and relationships introduced by the notification feature. All types live under `lib/src/notification/`.

---

## Overview

```text
                      TransferKitConfig (existing)
                              │
                              │ contains
                              ▼
                  TransferNotificationConfig
                  ├── flags (enable / per-type / per-state)
                  ├── throttleDuration
                  ├── grouping: NotificationGroupingMode
                  ├── uploadTemplate: TransferNotificationTemplate
                  └── downloadTemplate: TransferNotificationTemplate
                                        │
                                        │ used by
                                        ▼
       TransferNotificationCoordinator ◄─── observes ─── FileTaskRepository
                  │                                       (existing)
                  │ delegates to
                  ▼
       TransferNotificationPolicy.shouldNotify(...)
                  │
                  │ if true →
                  ▼
       TransferNotificationAdapter ◄─── built-in ── AwesomeNotificationAdapter
                  │                                  (one of many)
                  │ receives
                  ▼
       TransferNotificationPayload
```

---

## Entities

### 1. `TransferNotificationConfig`

**File**: `lib/src/notification/config/transfer_notification_config.dart`

**Purpose**: Carries every flag and template that controls notification behavior. Held inside `TransferKitConfig`.

| Field | Type | Default | Source FR | Notes |
| --- | --- | --- | --- | --- |
| `enabled` | `bool` | `false` | FR-001 | Master switch. False suppresses everything. |
| `uploadEnabled` | `bool` | `true` | FR-002 | Only effective when `enabled == true`. |
| `downloadEnabled` | `bool` | `true` | FR-002 | Only effective when `enabled == true`. |
| `showProgress` | `bool` | `true` | FR-003 | |
| `showCompletion` | `bool` | `true` | FR-003 | |
| `showErrors` | `bool` | `true` | FR-003 | |
| `showCancelled` | `bool` | `false` | FR-003 | Off by default — cancellations are user-initiated. |
| `showPaused` | `bool` | `false` | FR-003 | Off by default — usually a transient state. |
| `showRetry` | `bool` | `false` | FR-003 | Off by default — implementation detail of error recovery. |
| `throttleDuration` | `Duration` | `Duration(milliseconds: 1000)` | FR-004 | Per spec clarification Q4. |
| `grouping` | `NotificationGroupingMode` | `NotificationGroupingMode.perFile` | FR-006 | |
| `uploadTemplate` | `TransferNotificationTemplate` | `TransferNotificationTemplate.defaultUpload()` | FR-008 | |
| `downloadTemplate` | `TransferNotificationTemplate` | `TransferNotificationTemplate.defaultDownload()` | FR-008 | |
| `adapter` | `TransferNotificationAdapter?` | `null` → built-in | FR-010 | Optional; defaults to `AwesomeNotificationAdapter`. |
| `requestPermissionOnInit` | `bool` | `false` | FR-013 | Explicit opt-in for automatic permission request. |

**Constructors**:

- `const TransferNotificationConfig({...})` — full constructor with all named params and defaults above.
- `TransferNotificationConfig.disabled()` — convenience: every flag false. Used as the default when `TransferKitConfig.init()` is called without `notificationConfig`.
- `TransferNotificationConfig.uploadsOnly()` — convenience preset.
- `TransferNotificationConfig.downloadsOnly()` — convenience preset.

**Validation rules**:

- `throttleDuration` MUST be `> Duration.zero`. Constructor asserts.
- If `enabled == false`, the values of all other flags are ignored at runtime (FR-015).

**Relationships**:

- Owned by `TransferKitConfig` as `notificationConfig`.
- Read-only at runtime; replaced wholesale via `TransferKitConfig.instance.setNotificationConfig(newConfig)`.

---

### 2. `TransferNotificationTemplate`

**File**: `lib/src/notification/config/transfer_notification_template.dart`

**Purpose**: Customizable text and presentation for notifications, separated per transfer direction.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `title` | `String` | `"File transfer"` | Generic; overridden by direction-specific defaults. |
| `body` | `String?` | `null` | If null, falls back to runtime `payload.fileName`. |
| `progressText` | `String Function(double progress)?` | builds `"{percent}%"` | Receives 0.0–1.0. |
| `successText` | `String` | `"Transfer complete"` | |
| `failureText` | `String` | `"Transfer failed"` | |
| `cancelledText` | `String` | `"Transfer cancelled"` | |
| `pausedText` | `String` | `"Transfer paused"` | |
| `retryText` | `String` | `"Retrying transfer"` | |
| `groupedTitle` | `String Function(int total, int completed)?` | builds `"Transferring {completed}/{total}"` | For batch mode. |
| `iconKey` | `String?` | `null` | Adapter-specific (e.g. Android drawable resource name). |
| `channelKey` | `String?` | `null` | Adapter-specific. Falls back to adapter default. |
| `localization` | `Map<String, String>?` | `null` | Optional key → translation map; consumed by `resolveText`. |
| `resolveText` | `String Function(String key, TransferNotificationPayload payload)?` | `null` | Optional override that supersedes all string fields. |
| `actions` | `List<TransferNotificationAction>?` | `null` | Declared per R-010; built-in adapter ignores. |

**Static factories**:

- `TransferNotificationTemplate.defaultUpload()` — title `"Uploading file"`, success `"Upload complete"`.
- `TransferNotificationTemplate.defaultDownload()` — title `"Downloading file"`, success `"Download complete"`.

**Validation**:

- All string fields trimmed but allowed to be empty.
- `resolveText` takes precedence over plain fields when provided.

**Relationships**:

- Two instances per `TransferNotificationConfig` (upload + download).

---

### 3. `TransferNotificationAction`

**File**: `lib/src/notification/model/transfer_notification_action.dart`

**Purpose**: Declares an actionable button on a notification. v1: declared but built-in adapter ignores (R-010).

| Field | Type | Notes |
| --- | --- | --- |
| `key` | `String` | Identifier. Reserved keys: `"pause"`, `"resume"`, `"cancel"`, `"retry"`. |
| `label` | `String` | Localized button label. |
| `iconKey` | `String?` | Adapter-specific icon. |

**Routing**: When a custom adapter handles a tap, it MUST call `TransferKit.instance.handleNotificationAction(key, taskId)` which routes reserved keys to `TaskManagementService` and unknown keys to a developer-supplied callback (or no-ops).

---

### 4. `TransferNotificationPayload`

**File**: `lib/src/notification/model/transfer_notification_payload.dart`

**Purpose**: Immutable snapshot passed to the adapter for one notification event.

| Field | Type | Notes |
| --- | --- | --- |
| `taskId` | `String` | Task identifier (also the dedup key). |
| `groupId` | `String?` | Non-null when grouping is `batch`. |
| `transferType` | `TransferType` (enum: `upload`, `download`) | |
| `state` | `FileTaskState` | Existing enum; reused as-is. |
| `progress` | `double` | 0.0–1.0. For terminal states, 1.0 on success and last-known on failure. |
| `bytesTransferred` | `int?` | Optional, for adapters that show byte counts. |
| `totalBytes` | `int?` | Optional. |
| `fileName` | `String?` | Resolved from task. |
| `title` | `String` | Pre-resolved from template. |
| `body` | `String` | Pre-resolved from template. |
| `actions` | `List<TransferNotificationAction>` | Empty if template provided none. |
| `notificationId` | `int` | Stable per-task ID per R-004. |
| `timestamp` | `DateTime` | Event time. |

**Construction**: Built only by `TransferNotificationCoordinator` from current task state + active template; never constructed by consumer code.

---

### 5. `NotificationGroupingMode`

**File**: `lib/src/notification/model/notification_grouping_mode.dart`

```dart
enum NotificationGroupingMode {
  /// One notification per task.
  perFile,

  /// One grouped summary notification per groupId; individual task
  /// notifications suppressed.
  batch,

  /// No notifications shown at all (alternative to enabled = false at
  /// the per-batch level).
  none,
}
```

**Source FR**: FR-006.

---

### 6. `NotificationPermissionStatus`

**File**: `lib/src/notification/model/notification_permission_status.dart`

```dart
enum NotificationPermissionStatus {
  granted,
  denied,
  restricted,    // iOS-specific; on Android maps to denied at runtime
  notDetermined, // initial state and unsupported-platform return value
}
```

**Source FR**: FR-011, FR-012.

---

### 7. `TransferNotificationAdapter` (interface)

**File**: `lib/src/notification/adapter/transfer_notification_adapter.dart`

See [contracts/notification-adapter.md](./contracts/notification-adapter.md) for the full method contract.

---

### 8. `TransferNotificationPolicy`

**File**: `lib/src/notification/policy/transfer_notification_policy.dart`

**Purpose**: Pure-function decision engine. No state, no I/O.

**Signature**:

```dart
class TransferNotificationPolicy {
  const TransferNotificationPolicy(this.config);

  final TransferNotificationConfig config;

  /// Returns true if a notification should be emitted for the given event.
  bool shouldNotify({
    required TransferType transferType,
    required FileTaskState state,
    required NotificationEventKind kind, // progress | terminal | retry
  });
}

enum NotificationEventKind { progress, terminal, retry }
```

**Decision matrix** (when `config.enabled == true`):

| transferType | state | kind | uploadEnabled | downloadEnabled | shouldNotify |
| --- | --- | --- | --- | --- | --- |
| upload | * | * | false | * | false |
| download | * | * | * | false | false |
| * | running | progress | true | true | `config.showProgress` |
| * | completed | terminal | true | true | `config.showCompletion` |
| * | error | terminal | true | true | `config.showErrors` |
| * | cancelled | terminal | true | true | `config.showCancelled` |
| * | paused | progress | true | true | `config.showPaused` |
| * | running | retry | true | true | `config.showRetry` |
| * | cached | terminal | true | true | false (cache hits silent in v1) |
| * | waiting | progress | true | true | false (queued state never notifies) |

When `config.enabled == false`, returns `false` unconditionally (FR-015).

---

### 9. `TransferNotificationCoordinator`

**File**: `lib/src/notification/coordinator/transfer_notification_coordinator.dart`

**Purpose**: Wires task state events → policy → throttle → adapter. Owns per-task subscription state.

**Public surface**:

```dart
class TransferNotificationCoordinator {
  TransferNotificationCoordinator({
    required TransferNotificationConfig config,
    required TransferNotificationAdapter adapter,
    required FileTaskRepository repository,
  });

  /// Begins observing the repository. Idempotent.
  void start();

  /// Cancels every per-task subscription, dismisses any active notifications,
  /// and stops observing the repository. Idempotent.
  Future<void> dispose();

  /// Routes an action invoked from inside a notification (custom adapters).
  Future<void> handleAction(String actionKey, String taskId);
}
```

**Internal state**:

- `Map<String, _TaskSubscription> _subscriptions`
- `Map<String, _GroupAggregator> _groups` (used only when `config.grouping == batch`)
- `_TaskSubscription` holds: `Stopwatch`, optional trailing `Timer`, `previousState`, `lastPayload`.

**Lifecycle rules**:

- Subscription created lazily on first observed event for a task.
- Subscription disposed when state ∈ `{completed, error, cancelled, cached}` AND no further notifications are pending.
- All `try/catch` around `adapter.*` calls log at `debug` and never propagate (FR-014).

---

### 10. `FakeNotificationAdapter`

**File**: `test/src/notification/fake/fake_notification_adapter.dart`

**Purpose**: Test double. Records every call with timestamp and payload.

```dart
class FakeNotificationAdapter implements TransferNotificationAdapter {
  final List<RecordedCall> recordedCalls = [];
  NotificationPermissionStatus permissionStatus =
      NotificationPermissionStatus.granted;

  void clear();

  @override
  Future<void> showOrUpdateProgress(TransferNotificationPayload payload);
  // ... etc.
}

class RecordedCall {
  final String method;
  final TransferNotificationPayload? payload;
  final String? taskOrGroupId;
  final DateTime at;
}
```

---

## Modifications to Existing Entities

### `TransferKitConfig` (existing)

**File**: `lib/src/core/file_management_config.dart`

**Additions**:

- New private field `TransferNotificationConfig _notificationConfig = TransferNotificationConfig.disabled();`
- New named parameter on `init()`: `TransferNotificationConfig? notificationConfig`.
- New getter `TransferNotificationConfig get notificationConfig => _notificationConfig;`
- New mutator `void setNotificationConfig(TransferNotificationConfig config)`.
- Add to `toMap()`: `'notificationConfig': _notificationConfig.toDebugMap()`.

**No removals or renames** (Principle I).

### `BackgroundTransferService` (existing)

**File**: `lib/src/service/background_transfer_service.dart`

**Removals** (per R-001):

- All `awesome_notifications` imports and calls.
- Notification channel constants (`notificationChannelKey`, `notificationChannelName`, `notificationChannelDescription`, `channel()`).
- Notification ID range constants (`_progressNotificationIdStart`, etc.).
- `_createOrUpdateNotification()`, `_createOrUpdateBatchNotification()`, `_getProgressNotificationId()`, `_getSuccessNotificationId()`, `_getFailureNotificationId()`.

**Additions**: a single private field `TransferNotificationCoordinator? _coordinator` set during initialization (when notifications are enabled). The service emits lifecycle events as before; the coordinator handles all rendering.

---

## State Transitions Affecting Notifications

Notifications fire on the following observed transitions (assuming policy permits):

| From | To | Event Kind | Adapter Method |
| --- | --- | --- | --- |
| any | running (first time) | progress | `showOrUpdateProgress` |
| running | running (progress tick) | progress (throttled) | `showOrUpdateProgress` |
| running | paused | progress | `showOrUpdateProgress` (paused text) |
| paused | running | progress | `showOrUpdateProgress` |
| running | completed | terminal | `showCompletion` |
| any | error | terminal | `showError` |
| any | cancelled | terminal | `showCompletion` (with cancelledText) or `cancel` if `showCancelled == false` |
| any | cached | terminal | `cancel` (no notification per v1; silent cache hit) |
| running ←side channel | running | retry | `showOrUpdateProgress` (retryText) |

---

## Constants

- `kDefaultThrottleMs = 1000` (mirrored in `TransferNotificationConfig` default).
- `kNotificationIdRangeStart = 10000`, `kNotificationIdRangeSize = 29999` (R-004; mirrors current `BackgroundTransferService` ranges to preserve tray identity through migration).

---

## Public API additions (exported from `lib/transfer_kit.dart`)

- `TransferNotificationConfig`
- `TransferNotificationTemplate`
- `TransferNotificationAction`
- `TransferNotificationPayload`
- `TransferNotificationAdapter`
- `NotificationGroupingMode`
- `NotificationPermissionStatus`
- `NotificationEventKind`
- `TransferType`

The coordinator and policy are internal (`src/`) and NOT exported — consumers interact via `TransferKitConfig.instance.setNotificationConfig(...)` and `TransferKit.instance.checkNotificationPermission()` / `.requestNotificationPermission()`.
