# Migration Guide: TransferKit 2.x → 3.0.0

TransferKit 3.0.0 removes the hard dependency on Firebase Storage and
Cloud Firestore. The package is now provider-agnostic — you supply a
`TransferDriver` implementation at initialization time.

---

## What was removed

| Member / Symbol | Kind | Why removed |
|---|---|---|
| `FileTask.task` (`Task?`) | Field | Firebase `UploadTask`/`DownloadTask` — driver manages task internally |
| `FileTask.firebaseTask()` | Method | Firebase-specific |
| `FileTask.reference` | Property | Returns Firebase `Reference` |
| `FileTask.upload(UploadTask?)` | Named constructor | Firebase-typed parameter |
| `DateTimeExtension.toTimestamp()` | Extension method | Firestore `Timestamp` type |
| `ObjectExtension.objectToTimestamp()` | Extension method | Firestore `Timestamp` type |
| `ObjectExtension.objectToDateTime()` (Firestore overload) | Extension method | Accepts Firestore `Timestamp` |
| `MapExtension.getDocumentReference(tag)` | Extension method | Firestore `DocumentReference` type |
| `MapExtension.getTimestamp(tag)` | Extension method | Firestore `Timestamp` type |
| `MapExtension.mapCanConvertToFirebase()` | Extension method | Firestore serialization |
| `GeoPointExtension` (entire extension) | Extension | Extends Firestore `GeoPoint` |
| `firebase_storage: ^12.0.0` | pubspec dependency | No longer needed |
| `cloud_firestore: ^5.0.0` | pubspec dependency | No longer needed |

---

## What was added

| Symbol | Kind | Purpose |
|---|---|---|
| `TransferDriver` | Abstract interface | Core provider abstraction |
| `TransferCapabilities` | Immutable class | Driver capability declaration |
| `DownloadRequest` | Immutable class | Describes a download operation |
| `UploadRequest` | Immutable class | Describes an upload operation |
| `TransferProgressEvent` | Sealed class | Base type for driver stream events |
| `TransferProgressUpdate` | Final class | Intermediate progress event |
| `TransferCompleted` | Final class | Terminal success event |
| `TransferFailed` | Final class | Terminal failure event |
| `UnsupportedCapabilityException` | Exception class | Thrown for unsupported operations |
| `HttpDownloadDriver` | Concrete driver | Built-in HTTP/HTTPS download driver |
| `LocalFileCopyDriver` | Concrete driver | Built-in on-device file copy driver |

---

## Driver injection (required)

`TransferKitConfig.init()` now requires a `driver` parameter. There is
no default Firebase driver.

**Before (2.x):**
```dart
await TransferKitConfig.init(
  maxConcurrentDownloads: 3,
);
```

**After (3.0.0):**
```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(
    headers: {'Authorization': 'Bearer $myApiToken'},
  ),
  maxConcurrentDownloads: 3,
);
```

---

## Migration path for Firebase users

Implement a `FirebaseStorageDriver` adapter in your own codebase — no
changes are needed to `transfer_kit` itself:

```dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:transfer_kit/transfer_kit.dart';

class FirebaseStorageDriver implements TransferDriver {
  FirebaseStorageDriver({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  TransferCapabilities get capabilities => const TransferCapabilities(
        supportsUpload: true,
        supportsDownload: true,
        supportsPause: true,
        supportsResume: true,
        supportsCancel: true,
        supportsProgress: true,
      );

  @override
  Stream<TransferProgressEvent> download(DownloadRequest request) async* {
    final ref = _storage.refFromURL(request.source.toString());
    final localFile = File(request.localPath ?? _tempPath(request.taskId));
    final downloadTask = ref.writeToFile(localFile);

    await for (final snapshot in downloadTask.snapshotEvents) {
      yield TransferProgressUpdate(
        taskId: request.taskId,
        bytesTransferred: snapshot.bytesTransferred,
        totalBytes: snapshot.totalBytes,
      );
    }

    yield TransferCompleted(
      taskId: request.taskId,
      localPath: localFile.path,
    );
  }

  @override
  Stream<TransferProgressEvent> upload(UploadRequest request) async* {
    final ref = _storage.ref(request.destinationPath!);
    final uploadTask = ref.putFile(File(request.localPath));

    await for (final snapshot in uploadTask.snapshotEvents) {
      yield TransferProgressUpdate(
        taskId: request.taskId,
        bytesTransferred: snapshot.bytesTransferred,
        totalBytes: snapshot.totalBytes,
      );
    }

    final url = await ref.getDownloadURL();
    yield TransferCompleted(
      taskId: request.taskId,
      remoteIdentifier: url,
    );
  }

  @override
  Future<void> pause(String taskId) async { /* delegate to stored UploadTask */ }

  @override
  Future<void> resume(String taskId) async { /* delegate to stored UploadTask */ }

  @override
  Future<void> cancel(String taskId) async { /* delegate to stored Task */ }

  String _tempPath(String taskId) =>
      '${Directory.systemTemp.path}/transfer_kit_$taskId';
}
```

Then initialize:
```dart
await TransferKitConfig.init(driver: FirebaseStorageDriver());
```

---

## Testing with FakeTransferDriver

The package ships a `FakeTransferDriver` in `test/src/fake/` for offline
tests — no Firebase credentials, no network required:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:transfer_kit/transfer_kit.dart';
// FakeTransferDriver is in the test/ directory — copy or reference it:
import '<your_test_path>/fake_transfer_driver.dart';

void main() {
  test('download completes offline', () async {
    await TransferKitConfig.init(driver: FakeTransferDriver(progressSteps: 3));

    final driver = TransferKitConfig.instance.driver;
    final events = await driver
        .download(DownloadRequest(
          taskId: 'test_01',
          source: Uri.parse('fake://file.txt'),
        ))
        .toList();

    expect(events.last, isA<TransferCompleted>());
  });
}
```
