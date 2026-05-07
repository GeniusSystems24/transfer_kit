# Quickstart: Notification Control and UI Design

**Date**: 2026-05-07
**Feature**: [spec.md](./spec.md)
**Plan**: [plan.md](./plan.md)

This quickstart shows how a host application enables, configures, customizes, and tests TransferKit notifications after this feature lands.

---

## 1. Default behavior (post-upgrade)

After upgrading to the version that ships this feature, **TransferKit emits zero notifications by default**. Existing apps that were silently relying on the old built-in notifications will see no notifications until they opt in.

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  // notificationConfig omitted → notifications disabled
);

// Start an upload — runs as before, but no notification appears.
await transferKit.upload(...);
```

---

## 2. Enable notifications with the built-in adapter

```dart
import 'package:transfer_kit/transfer_kit.dart';

await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
    // every other flag uses defaults: progress on, completion on,
    // errors on, cancelled/paused/retry off, throttle 1 s, perFile grouping.
  ),
);

// Optionally request permission at a moment of your choosing.
final status = await TransferKit.instance.requestNotificationPermission();
if (status == NotificationPermissionStatus.granted) {
  // Free to start transfers; notifications will appear.
}
```

---

## 3. Show only completion and error notifications (no progress)

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
    showProgress: false,        // no progress spam
    showCompletion: true,
    showErrors: true,
    showCancelled: false,
    showPaused: false,
    showRetry: false,
  ),
);
```

---

## 4. Disable upload notifications, enable download notifications

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
    uploadEnabled: false,       // suppress all upload notifications
    downloadEnabled: true,      // downloads notify normally
  ),
);
```

---

## 5. Customize templates (different look for upload vs download)

```dart
final uploadTemplate = TransferNotificationTemplate(
  title: 'Sending file…',
  successText: 'File sent',
  failureText: 'Send failed',
  iconKey: '@drawable/ic_upload',
  channelKey: 'my_app_uploads',
);

final downloadTemplate = TransferNotificationTemplate(
  title: 'Receiving file…',
  successText: 'File ready',
  failureText: 'Download failed',
  iconKey: '@drawable/ic_download',
  channelKey: 'my_app_downloads',
);

await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: TransferNotificationConfig(
    enabled: true,
    uploadTemplate: uploadTemplate,
    downloadTemplate: downloadTemplate,
  ),
);
```

---

## 6. Add localization

```dart
String resolve(String key, TransferNotificationPayload p) {
  // Route through your app's localization system.
  return MyL10n.of(navigatorKey.currentContext!).t(key, args: {
    'fileName': p.fileName ?? '',
    'percent': (p.progress * 100).toStringAsFixed(0),
  });
}

final template = TransferNotificationTemplate(
  resolveText: resolve, // overrides plain string fields
);
```

---

## 7. Use grouped batch notifications

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
    grouping: NotificationGroupingMode.batch,
  ),
);

// 5-file batch upload now produces exactly ONE grouped notification
// summarising overall progress, instead of 5 separate notifications.
await transferKit.uploadGroup(groupId: 'photos-2026-05-07', files: [...]);
```

---

## 8. Tune throttle for slower-update notifications

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
    throttleDuration: Duration(seconds: 3), // less frequent updates
  ),
);
```

---

## 9. Provide a custom adapter (replace the built-in)

```dart
class MyNotificationAdapter implements TransferNotificationAdapter {
  @override
  Future<NotificationPermissionStatus> checkPermission() async => ...;

  @override
  Future<void> showOrUpdateProgress(TransferNotificationPayload p) async {
    // Render however you like — flutter_local_notifications, native channel,
    // in-app banner, anything.
  }

  // ... implement remaining methods ...
}

await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: TransferNotificationConfig(
    enabled: true,
    adapter: MyNotificationAdapter(),
  ),
);
```

---

## 10. Toggle notifications at runtime

```dart
// Enable or change notification config without re-initializing TransferKit.
TransferKitConfig.instance.setNotificationConfig(
  const TransferNotificationConfig(enabled: false),
);
```

---

## 11. Test notification behavior with `FakeNotificationAdapter`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/transfer_kit.dart';
import '../../src/notification/fake/fake_notification_adapter.dart';

void main() {
  test('completion notification fires once', () async {
    final fake = FakeNotificationAdapter();
    await TransferKitConfig.init(
      driver: FakeTransferDriver(),
      notificationConfig: TransferNotificationConfig(
        enabled: true,
        adapter: fake,
      ),
    );

    await transferKit.download(taskId: 't1', url: '...');

    // Wait for the fake driver to emit completion.
    await fakeDriver.completeTask('t1');

    final completionCalls = fake.recordedCalls
        .where((c) => c.method == 'showCompletion')
        .toList();
    expect(completionCalls, hasLength(1));
    expect(completionCalls.single.payload!.taskId, 't1');
  });
}
```

---

## Acceptance walkthroughs (one per User Story)

- **US1 (Disable all)** — Step 1 above. No notifications produced.
- **US2 (Per-type toggle)** — Step 4 above.
- **US3 (Selective lifecycle)** — Step 3 above.
- **US4 (Throttling)** — Default config; verify only one update per 1000 ms via `FakeNotificationAdapter` timestamps.
- **US5 (Customizable design)** — Steps 5 + 6 above.
- **US6 (Batch grouping)** — Step 7 above.
- **US7 (Permission)** — Step 2 above; verify `checkNotificationPermission()` returns status without dialog.

---

## Platform notes

| Platform | Behavior |
| --- | --- |
| Android | Full support. Channel registered lazily on first notification. |
| iOS | Full support. Permission must be requested before first notification appears (call `requestNotificationPermission()` once). |
| macOS / Windows / Linux / Web | Notification methods silently no-op. `checkPermission()` returns `notDetermined`. Transfers run normally. |

For more detail see [README.md](../../README.md) "Notifications" section (added by this feature).
