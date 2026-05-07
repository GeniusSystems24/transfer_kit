# Feature Specification: Notification Control and UI Design

**Feature Branch**: `003-notification-control-ui`
**Created**: 2026-05-07
**Status**: Draft
**Input**: User description: "Improve TransferKit notification control and notification UI/design for file transfer tasks."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Disable All Notifications (Priority: P1)

A developer wants to turn off every notification that TransferKit emits across all transfer types and lifecycle states. They set a single top-level flag and expect that no notifications appear at runtime, with zero code changes in individual task handlers.

**Why this priority**: The most fundamental control needed. Without it, all other notification toggles are secondary. An app that must silence notifications has no safe fallback today.

**Independent Test**: Initialize TransferKit with `enableNotifications: false`, start an upload and a download, and verify that no notification appears at any lifecycle stage (progress, completion, error).

**Acceptance Scenarios**:

1. **Given** TransferKit is initialized with `enableNotifications: false`, **When** a file upload reaches 100% and completes, **Then** no notification is shown.
2. **Given** TransferKit is initialized with `enableNotifications: false`, **When** a download fails with an error, **Then** no notification is shown.
3. **Given** TransferKit is initialized with `enableNotifications: false`, **When** a task is cancelled, **Then** no notification is shown.

---

### User Story 2 - Per-Type Notification Toggle (Priority: P1)

A developer wants upload and download notifications to behave independently. They need to enable download-completion notifications while suppressing all upload-related notifications, or vice versa.

**Why this priority**: Upload and download workflows often serve different UX needs. Suppressing one type without affecting the other is a foundational control.

**Independent Test**: Enable only `enableDownloadNotifications: true` and `enableUploadNotifications: false`. Start both an upload and a download. Verify notifications appear only for the download.

**Acceptance Scenarios**:

1. **Given** `enableUploadNotifications: false` and `enableDownloadNotifications: true`, **When** an upload completes, **Then** no notification is shown.
2. **Given** `enableUploadNotifications: false` and `enableDownloadNotifications: true`, **When** a download completes, **Then** a completion notification is shown.
3. **Given** `enableUploadNotifications: true` and `enableDownloadNotifications: false`, **When** a download fails, **Then** no notification is shown.

---

### User Story 3 - Selective Lifecycle Notifications (Priority: P2)

A developer wants only completion and error notifications — not progress, paused, cancelled, or retry notifications. They configure individual lifecycle flags and expect that only the selected stages trigger a notification.

**Why this priority**: Progress notifications are often noisy for fast or background transfers. Fine-grained lifecycle control prevents notification spam without turning everything off.

**Independent Test**: Set `showProgressNotifications: false`, `showCompletionNotifications: true`, `showErrorNotifications: true`, and all others to false. Run a transfer through all states. Verify notifications appear only for completion and error.

**Acceptance Scenarios**:

1. **Given** only `showCompletionNotifications: true`, **When** a task progresses from 0% to 99%, **Then** no progress notification is shown.
2. **Given** only `showCompletionNotifications: true`, **When** a task reaches 100%, **Then** a completion notification is shown.
3. **Given** only `showErrorNotifications: true`, **When** a task fails, **Then** an error notification is shown.
4. **Given** `showCancelledNotifications: false`, **When** a task is cancelled, **Then** no notification is shown.

---

### User Story 4 - Throttled Progress Notifications (Priority: P2)

A user running a large file transfer wants smooth progress feedback without notification spam. The system should update a single persistent notification rather than posting new ones for each progress event, and should throttle updates to a configurable interval.

**Why this priority**: Without throttling, rapid progress events can flood the notification tray, degrade performance, and confuse users.

**Independent Test**: Start a transfer that emits progress events every 100 ms with `notificationThrottleDuration: 2s`. Monitor notifications over 10 seconds. Verify at most 5 updates appear and no duplicate notification records exist.

**Acceptance Scenarios**:

1. **Given** `notificationThrottleDuration: 2000ms` and a transfer emitting events every 200 ms, **When** the transfer runs for 10 seconds, **Then** at most 5 progress notification updates occur.
2. **Given** a running transfer, **When** a new progress event arrives before the throttle window expires, **Then** the existing notification is updated (not a new one created).
3. **Given** a transfer that completes before the next throttle tick, **When** completion is reached, **Then** a completion notification fires immediately regardless of the remaining throttle window.

---

### User Story 5 - Customizable Notification Design (Priority: P2)

A developer wants upload progress notifications to display a custom icon, title, and body text that differs from download notifications. They also want localized strings for success and failure messages.

**Why this priority**: Visual consistency with the host app's branding is a common requirement. Without design hooks, developers are forced to use hard-coded text.

**Independent Test**: Provide a custom notification template with a distinct title for uploads vs downloads. Run both. Verify each notification renders its respective custom title and body.

**Acceptance Scenarios**:

1. **Given** a custom upload template with `title: "Uploading…"`, **When** an upload starts, **Then** the notification title reads "Uploading…".
2. **Given** localized strings provided in Arabic, **When** the device locale is Arabic, **Then** the notification body displays the Arabic string.
3. **Given** a custom success body `"Your file is ready"`, **When** a download completes, **Then** the notification body reads "Your file is ready".

---

### User Story 6 - Batch Transfer Grouped Notification (Priority: P3)

A developer initiating a multi-file upload wants a single grouped notification summarizing the overall batch, rather than one notification per file.

**Why this priority**: Multi-file transfers with per-file notifications overwhelm the notification tray. Grouping is a quality-of-life improvement once core controls are in place.

**Independent Test**: Initiate a batch of 5 uploads with `notificationGrouping: batch`. Verify exactly one group notification appears summarizing all 5 tasks, not 5 individual notifications.

**Acceptance Scenarios**:

1. **Given** `notificationGrouping: batch` and 5 simultaneous uploads, **When** the batch starts, **Then** one grouped notification is shown with overall progress.
2. **Given** `notificationGrouping: perFile` and 5 simultaneous uploads, **When** the batch starts, **Then** 5 individual notifications are shown.
3. **Given** `notificationGrouping: none`, **When** a batch of uploads runs, **Then** no notifications are shown for any file.

---

### User Story 7 - Notification Permission Guidance (Priority: P3)

A developer wants TransferKit to check whether notification permissions have been granted before attempting to show any notification, and to expose a helper they can call to request permissions at an appropriate time in their app flow.

**Why this priority**: Silent failures when permissions are missing are hard to diagnose. Explicit guidance prevents unexpected permission dialogs triggered by the library.

**Independent Test**: Call `TransferKit.checkNotificationPermission()` on a device with permissions denied. Verify it returns a denied status without triggering a system permission dialog.

**Acceptance Scenarios**:

1. **Given** notification permissions are not granted, **When** a transfer completes, **Then** no system notification appears and no permission dialog is shown.
2. **Given** a developer calls the permission-check API, **When** permissions are denied, **Then** the API returns a `denied` status.
3. **Given** a developer calls the permission-request API, **When** the user grants permission, **Then** the API returns a `granted` status and subsequent transfer notifications are shown.

---

### Edge Cases

- What happens when `enableNotifications: true` but `enableUploadNotifications: false` and `enableDownloadNotifications: false`? No notification should appear for any transfer.
- What happens if the notification provider fails to display a notification (e.g., system-level error)? The failure should be silently swallowed — transfer operations must not be blocked.
- What happens when a task transitions directly from `waiting` to `cancelled` without ever running? Notification state should respect `showCancelledNotifications` without creating a progress notification.
- What happens when a retrying task retries faster than `notificationThrottleDuration`? The notification updates at the throttle rate; rapid retries do not create duplicate notifications.
- What happens when both per-type and global flags conflict (e.g., `enableNotifications: false` but `enableUploadNotifications: true`)? The global flag takes precedence.
- What happens if a developer provides a partial custom template? Missing fields fall back to default text.
- What happens during a batch transfer where individual files complete at different times? The group notification updates to reflect overall progress.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a global `enableNotifications` flag that, when false, suppresses all notifications regardless of any other configuration.
- **FR-002**: The system MUST provide `enableUploadNotifications` and `enableDownloadNotifications` flags that independently control notifications for each transfer type.
- **FR-003**: The system MUST provide per-lifecycle flags: `showProgressNotifications`, `showCompletionNotifications`, `showErrorNotifications`, `showCancelledNotifications`, `showPausedNotifications`, `showRetryNotifications`.
- **FR-004**: The system MUST support a `notificationThrottleDuration` that prevents more than one progress notification update within the specified time window for the same task.
- **FR-005**: The system MUST update an existing notification record instead of creating a new one when a progress event arrives for an already-notified task.
- **FR-006**: The system MUST support a `notificationGrouping` configuration with at least three modes: `perFile` (one notification per task), `batch` (one grouped notification for all tasks in a batch), and `none` (no notifications).
- **FR-007**: The system MUST reflect each task lifecycle state in notifications: `waiting`, `running`, `paused`, `completed`, `cached`, `error`, `cancelled`, `retrying`.
- **FR-008**: The system MUST allow developers to supply a notification template that customizes title, body, progress text, success text, failure text, and grouped notification title independently for uploads and downloads.
- **FR-009**: The system MUST support localization strings within the notification template so developers can provide translated text.
- **FR-010**: Notification logic MUST be isolated behind an adapter interface so the underlying notification provider can be replaced without changing transfer or configuration code.
- **FR-011**: The system MUST expose a permission-check API that returns the current notification permission status without triggering a system dialog.
- **FR-012**: The system MUST expose a permission-request API that developers can call at a time of their choosing to request notification permissions.
- **FR-013**: The system MUST NOT request notification permissions automatically unless explicitly configured to do so.
- **FR-014**: A notification failure (e.g., provider error) MUST NOT interrupt or fail the underlying transfer operation.
- **FR-015**: The global `enableNotifications: false` flag MUST take precedence over all per-type and per-lifecycle flags.

### Key Entities

- **NotificationConfig**: Holds all notification control flags, throttle duration, grouping mode, and the active template. Attached to the existing `FileManagementConfig`.
- **NotificationTemplate**: Carries customizable text fields (title, body, progress text, success text, failure text, grouped title, localization strings) with separate instances per transfer direction.
- **NotificationAdapter**: Interface that notification providers implement; receives a `NotificationPayload` and is responsible for display, update, and dismissal.
- **NotificationPayload**: Represents a single notification event carrying task ID, task state, progress percentage, and resolved display strings.
- **NotificationPermissionStatus**: Enum with values `granted`, `denied`, `restricted`, `notDetermined`.
- **BatchNotificationGroup**: Groups multiple task notifications under a single summary notification identified by a batch ID.

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can silence all TransferKit notifications by changing a single configuration value — no other code changes required.
- **SC-002**: A transfer that emits progress events more frequently than the configured throttle interval produces no more than one notification update per throttle window per task.
- **SC-003**: A batch of 10 simultaneous transfers with `notificationGrouping: batch` produces exactly one active notification (not 10) in the notification tray throughout the batch.
- **SC-004**: A developer can swap the notification provider (from one package to another) by implementing one adapter interface without modifying any transfer, repository, or configuration code.
- **SC-005**: 100% of notification configuration options are expressed through `FileManagementConfig` — no notification behavior is hard-coded outside configuration.
- **SC-006**: Automated tests using a fake notification adapter achieve full branch coverage of notification decision logic (enable/disable, throttle, lifecycle state transitions, grouping modes).
- **SC-007**: The permission-check API returns a status value in under 100 ms without presenting a system dialog.
- **SC-008**: Notification failures produce no visible effect on transfer completion rates or reported task states.

---

## Assumptions

- Notification display capability is provided by a package already present in the host application; TransferKit's adapter interface will wrap it.
- The existing `FileManagementConfig` initialization pattern (singleton, `init()` method) will be extended — no new top-level entry point is needed.
- Grouped batch notifications use a developer-supplied or auto-generated batch ID to correlate tasks; TransferKit does not manage batch grouping at the transfer-scheduling level.
- Platform permission APIs differ per platform; the permission helper exposes a unified API that delegates to the adapter, which handles platform-specific behavior.
- Compact and expanded notification content (e.g., Android BigPicture, iOS rich notifications) are considered optional adapter capabilities; the core template covers text fields only.
- Notification actions (e.g., "Pause", "Cancel" buttons in the notification) are defined as optional adapter capabilities and are out of scope for the core template but may be declared in the template for adapters that support them.
- The `cached` task state produces no notification by default; an optional `showCacheHitNotifications` flag may be added but is not mandatory for the initial implementation.
- Localization strings in the template are keyed maps supplied by the developer; TransferKit does not ship built-in translations.
- The README and CHANGELOG updates are in scope and will be delivered alongside the implementation.
