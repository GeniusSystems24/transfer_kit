/speckit.tasks

Generate implementation tasks for notification control and notification UI/design.

## Task Group 1: Audit

- [ ] Search notification imports and usages.
- [ ] Identify direct `awesome_notifications` usage.
- [ ] Identify current notification behavior.
- [ ] Document current gaps.

Acceptance:
- Audit summary exists.

## Task Group 2: Configuration

- [ ] Add `TransferNotificationConfig`.
- [ ] Add global enable/disable.
- [ ] Add upload/download toggles.
- [ ] Add progress/completion/error/cancelled/paused/retry toggles.
- [ ] Add throttle duration.
- [ ] Add grouping mode.

Acceptance:
- Config has sensible defaults.
- Config can be initialized through TransferKit configuration.

## Task Group 3: Adapter Abstraction

- [ ] Add `TransferNotificationAdapter`.
- [ ] Add fake adapter for tests.
- [ ] Add concrete adapter for current notification package if retained.
- [ ] Remove direct notification package usage from core logic.

Acceptance:
- Tests can verify notification behavior without platform notification APIs.

## Task Group 4: Notification Policy

- [ ] Add policy class to decide notification behavior.
- [ ] Handle task type.
- [ ] Handle task state.
- [ ] Handle permission result.
- [ ] Handle foreground/background if available.
- [ ] Handle cache hit behavior.

Acceptance:
- Decision logic is testable.

## Task Group 5: Templates and Design

- [ ] Add default upload template.
- [ ] Add default download template.
- [ ] Add completion/error/cancelled templates.
- [ ] Add customizable title/body/progress builders.
- [ ] Support localization-friendly callbacks.

Acceptance:
- Developer can customize notification text and visual metadata.

## Task Group 6: Duplicate Prevention

- [ ] Use stable notification ID per task.
- [ ] Update progress notifications instead of creating duplicates.
- [ ] Throttle progress updates.
- [ ] Add tests for repeated progress events.

Acceptance:
- No notification spam during high-frequency progress updates.

## Task Group 7: Batch Notifications

- [ ] Add grouping mode support.
- [ ] Add grouped notification payload.
- [ ] Add tests for batch transfer notification behavior.

Acceptance:
- Batch transfers can use per-task or grouped notifications.

## Task Group 8: Documentation

- [ ] Update README.md.
- [ ] Add notification configuration examples.
- [ ] Add custom template examples.
- [ ] Add permission behavior notes.
- [ ] Update CHANGELOG.md.

## Definition of Done

- `dart format .` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- Notification logic is adapter-based and testable.
- Notification behavior is documented.
- Firebase removal is not included in this task.
