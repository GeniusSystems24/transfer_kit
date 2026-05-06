/speckit.plan

Create a technical implementation plan for notification control and notification UI/design.

## Tech Stack

- Flutter / Dart
- Existing TransferKit task lifecycle
- Existing notification dependency only if retained
- Fake notification adapter for tests
- `flutter_test`

## Architecture Direction

Introduce notification orchestration as a separate layer.

Recommended components:

1. `TransferNotificationConfig`
   - Stores global and per-type notification settings.

2. `TransferNotificationAdapter`
   - Abstract interface for showing/updating/cancelling notifications.

3. `AwesomeNotificationAdapter`
   - Optional concrete adapter if `awesome_notifications` remains.

4. `TransferNotificationTemplate`
   - Defines title/body/progress text/design metadata.

5. `TransferNotificationPolicy`
   - Decides whether a notification should be shown for a task event.

6. `TransferNotificationCoordinator`
   - Listens to task state changes.
   - Applies policy.
   - Applies throttling.
   - Calls adapter.

## Recommended Configuration

```dart
class TransferNotificationConfig {
  final bool enabled;
  final bool uploadEnabled;
  final bool downloadEnabled;
  final bool showProgress;
  final bool showCompletion;
  final bool showErrors;
  final bool showCancelled;
  final bool showPaused;
  final Duration throttleDuration;
  final TransferNotificationGrouping grouping;
  final TransferNotificationTemplate uploadTemplate;
  final TransferNotificationTemplate downloadTemplate;
}
```

## Notification Adapter

```dart
abstract interface class TransferNotificationAdapter {
  Future<bool> areNotificationsAllowed();

  Future<void> showOrUpdateProgress(TransferNotificationPayload payload);

  Future<void> showCompletion(TransferNotificationPayload payload);

  Future<void> showError(TransferNotificationPayload payload);

  Future<void> cancel(String taskId);

  Future<void> cancelGroup(String groupId);
}
```

## Implementation Phases

### Phase 1: Audit current notification usage

- Search all notification-related imports.
- Identify direct calls to notification packages.
- Identify notification behavior in widgets/services.
- Identify missing configuration.

### Phase 2: Add notification config

- Add global enable/disable.
- Add per-type upload/download enable/disable.
- Add state-specific toggles.
- Add throttling settings.

### Phase 3: Add adapter abstraction

- Add notification adapter interface.
- Add fake adapter for tests.
- Move package-specific logic behind adapter.

### Phase 4: Add notification policy

- Decide whether to notify based on:
  - task state,
  - task type,
  - config,
  - permission,
  - foreground/background if available,
  - batch/group mode.

### Phase 5: Add templates/design

- Add default templates.
- Add customizable templates.
- Support upload/download separation.
- Support localization through callbacks or string builders.

### Phase 6: Add duplicate prevention and throttling

- Use stable notification ID per task.
- Update progress notification instead of creating new one.
- Throttle progress updates.

### Phase 7: Batch/group notifications

- Add grouping mode:
  - none,
  - perTask,
  - perGroup.
- Add tests for group behavior.

### Phase 8: Docs and tests

- Add fake adapter tests.
- Update README.md.
- Update CHANGELOG.md.
- Add platform limitation notes.

## Test Plan

- Notifications disabled: no adapter call.
- Upload notifications disabled: upload emits no notifications.
- Download notifications enabled: download progress emits notification.
- Progress throttling prevents spam.
- Completion notification is shown once.
- Error notification is shown once.
- Cancelled notification follows config.
- Batch grouped notification uses group ID.
- Fake adapter receives expected payloads.

## Risks

- Notification packages are platform-sensitive.
- Permission behavior may differ across Android/iOS.
- Notification actions can add complexity.
- Too many notifications may annoy users.
- Direct dependency on a notification package may reduce flexibility.

## Rollback Strategy

- Keep notification system optional.
- Default to safe minimal behavior.
- Hide package-specific implementation behind adapter.
