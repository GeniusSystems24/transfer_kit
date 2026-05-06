/speckit.specify

Improve TransferKit notification control and notification UI/design for file transfer tasks.

This task focuses on giving developers better control over when notifications appear, how they behave, and how they look.

## Problem

TransferKit includes file transfer operations that may run for a long time.
Users need clear progress feedback, but notifications must not be noisy, duplicated, misleading, or hard-coded.

The package should provide configurable notification behavior for upload/download progress, completion, failure, cancellation, pause, and retry.

## Goals

1. Centralize notification control.
2. Allow notifications to be enabled or disabled globally.
3. Allow notifications to be enabled or disabled per transfer type.
4. Allow notifications to be customized by design/template.
5. Avoid duplicate notifications for the same task.
6. Make notification behavior follow task lifecycle.
7. Support grouped/batch transfer notifications.
8. Respect platform permission requirements.
9. Keep notification implementation decoupled from core transfer logic where possible.
10. Update README.md and CHANGELOG.md.

## Functional Requirements

### Notification control

TransferKit must provide configuration for:

- enableNotifications,
- enableUploadNotifications,
- enableDownloadNotifications,
- showProgressNotifications,
- showCompletionNotifications,
- showErrorNotifications,
- showCancelledNotifications,
- showPausedNotifications,
- showRetryNotifications,
- notificationThrottleDuration,
- notificationGrouping.

### Notification lifecycle

Notifications must reflect task state:

- waiting: optional queued notification,
- running: progress notification,
- paused: paused notification or progress freeze,
- completed: completion notification,
- cached: optional cache hit notification or no notification,
- error: failure notification,
- cancelled: cancellation notification,
- retrying: retry notification.

### Notification design

Developers must be able to customize:

- title,
- body,
- progress text,
- icon/channel/category if supported,
- grouped notification title,
- success/failure text,
- compact and expanded content,
- actions if supported,
- localization strings.

### Notification provider boundary

Notification logic must be abstracted behind a service/interface so TransferKit is not tightly locked to one notification package.

If the package continues to use `awesome_notifications`, it must be isolated behind an adapter.

### Duplicate prevention

The same task must not create repeated notifications for every progress event.

Progress notifications must be throttled and updated instead of creating new notification records.

### Batch notifications

For multi-file transfers, TransferKit should support:

- one notification per file,
- one grouped batch notification,
- or no notifications,
based on configuration.

### Permissions

Notification permission handling must be explicit.

TransferKit should not unexpectedly request notification permission unless configured.

The package must expose guidance or helper APIs for permission checks if supported.

## Non-Goals

- Do not redesign the entire Flutter widget system.
- Do not implement Firebase removal here.
- Do not change cache behavior here except where notifications depend on task state.
- Do not add platform-specific native code unless required and approved.

## User Stories

1. As a developer, I want to disable all TransferKit notifications.

2. As a developer, I want to show only completion and failure notifications, not progress notifications.

3. As a developer, I want upload notifications to look different from download notifications.

4. As a developer, I want batch transfer notifications to be grouped.

5. As a user, I want progress notifications to update smoothly without spam.

6. As a developer, I want to localize notification text.

## Acceptance Criteria

- Notification behavior is controlled through configuration.
- Notification rendering/design is template-based or adapter-based.
- Duplicate progress notifications are prevented.
- Notification updates are throttled.
- Batch notification behavior is configurable.
- Permission behavior is documented.
- README.md has notification examples.
- CHANGELOG.md documents the change.
- Tests cover notification decision logic using a fake notification adapter.
