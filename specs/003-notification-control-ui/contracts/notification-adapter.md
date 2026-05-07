# Contract: `TransferNotificationAdapter`

**File**: `lib/src/notification/adapter/transfer_notification_adapter.dart`
**Status**: v1 stable
**Owner**: TransferKit notification orchestration layer

This document specifies the public contract for the notification adapter interface — the boundary that lets developers swap or replace TransferKit's notification implementation.

---

## Purpose

`TransferNotificationAdapter` is the abstraction boundary between TransferKit's notification orchestration (config, policy, coordinator) and any concrete notification implementation. The interface is the **only** thing the orchestration layer depends on; the built-in `AwesomeNotificationAdapter` is one of many possible implementations.

This mirrors `TransferDriver` (Principle VI). No `awesome_notifications` import or call MAY appear outside `awesome_notification_adapter.dart`.

---

## Interface

```dart
/// Renders, updates, and dismisses notifications for transfer task events.
///
/// Implementations MUST satisfy the following contract. Implementations MAY
/// be no-ops on platforms they do not support; they MUST NOT throw in that
/// case.
abstract interface class TransferNotificationAdapter {
  /// Returns the current notification permission status WITHOUT showing
  /// any system dialog.
  ///
  /// MUST return in under 100 ms (SC-007).
  /// MUST return [NotificationPermissionStatus.notDetermined] on platforms
  /// where notifications are not supported.
  Future<NotificationPermissionStatus> checkPermission();

  /// Requests notification permission from the user, possibly displaying
  /// a system dialog.
  ///
  /// MUST be a no-op returning [NotificationPermissionStatus.notDetermined]
  /// on unsupported platforms.
  /// MUST NOT be called automatically by TransferKit unless
  /// [TransferNotificationConfig.requestPermissionOnInit] is true (FR-013).
  Future<NotificationPermissionStatus> requestPermission();

  /// Shows a new progress notification for [payload.taskId] OR updates the
  /// existing one. Implementations MUST use [payload.notificationId] as the
  /// stable identity so duplicate notifications are not created (FR-005).
  ///
  /// Called for: state == running (progress ticks, throttled by coordinator),
  ///             state == paused, retry events.
  Future<void> showOrUpdateProgress(TransferNotificationPayload payload);

  /// Shows a terminal completion notification for [payload.taskId].
  ///
  /// Implementations SHOULD reuse the same notification id as the progress
  /// notification so the tray entry transitions in place (FR-005).
  ///
  /// Called for: state == completed, and state == cancelled when
  /// `showCancelled` is true.
  Future<void> showCompletion(TransferNotificationPayload payload);

  /// Shows a terminal error notification for [payload.taskId].
  ///
  /// Called for: state == error.
  Future<void> showError(TransferNotificationPayload payload);

  /// Cancels (dismisses from the tray) the notification associated with
  /// [taskId]. No-op if no notification exists for that id.
  Future<void> cancel(String taskId);

  /// Cancels all notifications associated with [groupId]. No-op if no
  /// grouped notification exists.
  Future<void> cancelGroup(String groupId);

  /// Releases any platform resources (channels, listeners) owned by this
  /// adapter. After [dispose] returns, no further calls SHOULD be made.
  Future<void> dispose();
}
```

---

## Behavioral Guarantees Required of Implementations

### G-1: Idempotent identity

`showOrUpdateProgress(payload)` MUST be safe to call repeatedly with the same `payload.notificationId`. The first call creates the notification; subsequent calls update it in place. No duplicate tray entries.

### G-2: Failures are silent

Any internal failure (platform error, permission revoked mid-call, channel not registered) MUST NOT propagate as an unhandled exception. Implementations SHOULD:

- Log at `debug` level via the existing TransferKit logger (no new dependency).
- Return a completed future.
- Allow subsequent calls to succeed once the underlying issue clears.

This guarantee is enforced by the coordinator (which `try/catch`es every adapter call), but adapters SHOULD also handle their own errors to enable best-effort delivery.

### G-3: Sensitive data must not leak by default

Implementations MUST NOT include the following in notification body or title unless the developer explicitly placed them in the template:

- Signed URLs.
- Authentication tokens.
- Full file paths (file *names* are fine; full paths are not).
- Internal task IDs (use `payload.fileName` instead).

### G-4: Permission queries are cheap

`checkPermission()` MUST NOT trigger any system dialog. It MUST complete in under 100 ms on a normally-loaded device (SC-007). Implementations that need to consult the OS asynchronously SHOULD cache the result and refresh on `requestPermission()`.

### G-5: Unsupported platform behavior

On any platform not declared in the implementation's support matrix:

- All notification methods (`showOrUpdateProgress`, `showCompletion`, `showError`, `cancel`, `cancelGroup`) MUST return immediately with no error.
- `checkPermission()` and `requestPermission()` MUST return `NotificationPermissionStatus.notDetermined`.
- `dispose()` MUST succeed.

### G-6: Threading

Implementations MUST be safe to call from the main isolate. They are NOT required to be safe from background isolates; the coordinator runs in the same isolate as the transfer driver.

### G-7: Action routing

If the implementation supports notification actions, taps MUST be routed via `TransferKit.instance.handleNotificationAction(actionKey, taskId)`. Adapters MUST NOT directly mutate task state — that responsibility lives in `TaskManagementService`.

---

## Built-in Implementation: `AwesomeNotificationAdapter`

**File**: `lib/src/notification/adapter/awesome_notification_adapter.dart`

**Support matrix**:

| Platform | `show*` | `cancel*` | `checkPermission` | `requestPermission` |
| --- | --- | --- | --- | --- |
| Android | ✅ | ✅ | ✅ | ✅ |
| iOS | ✅ | ✅ | ✅ | ✅ |
| macOS | no-op | no-op | `notDetermined` | `notDetermined` |
| Windows | no-op | no-op | `notDetermined` | `notDetermined` |
| Linux | no-op | no-op | `notDetermined` | `notDetermined` |
| Web | no-op | no-op | `notDetermined` | `notDetermined` |

**Channel registration**: lazy on first `show*` call. The channel uses these defaults (overridable per template via `template.channelKey`):

- `channelKey`: `"transfer_kit_default"`
- `channelName`: `"File Transfers"`
- `importance`: `High`
- `playSound`: `true`
- `enableVibration`: `true`
- `locked`: `true`

**Notification ID derivation**: `payload.notificationId` is used as-is. The coordinator computes it via `kNotificationIdRangeStart + (taskId.hashCode.abs() % kNotificationIdRangeSize)`.

**Action handling**: ignored in v1 per spec clarification Q5 / R-010. The field is read but no buttons are rendered.

---

## Test Implementation: `FakeNotificationAdapter`

**File**: `test/src/notification/fake/fake_notification_adapter.dart` (test only)

**Support matrix**: all platforms (it never touches the OS).

**Inspectability**: every method call is appended to `recordedCalls` as a `RecordedCall { method, payload, taskOrGroupId, at }`. Tests assert against this list.

**Permission**: returns `permissionStatus` (defaults to `granted`, settable per test).

This is the canonical test double for any test that needs to verify notification decisions or rendering — analogous to `FakeTransferDriver` (Principle VI).

---

## Versioning

Adding methods to this interface in v2+ is a **breaking change** for existing custom adapters. To remain non-breaking, new optional capabilities SHOULD be added via a sidecar interface (e.g., `TransferNotificationActionsAdapter` mixin) so adapters can declare conformance independently. The `actions` field on `TransferNotificationTemplate` is already declared in v1 to enable this evolution path.
