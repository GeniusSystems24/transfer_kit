# Quickstart: Provider-Agnostic TransferKit 3.0.0

**Phase 1 output** | **Date**: 2026-05-07

This document shows how to use TransferKit 3.0.0 with the built-in drivers and how to implement a custom driver. It is the source of truth for README.md and MIGRATION.md examples.

---

## Setup

```yaml
# pubspec.yaml
dependencies:
  transfer_kit: ^3.0.0
```

No Firebase packages required.

---

## Initialize with a built-in driver

### HTTP download only

```dart
import 'package:transfer_kit/transfer_kit.dart';

await TransferKitConfig.init(
  driver: HttpDownloadDriver(
    // Auth headers are driver-level — not per-request
    headers: {'Authorization': 'Bearer $myApiToken'},
  ),
);
```

### Local file copy (useful for local workflows and testing)

```dart
await TransferKitConfig.init(
  driver: LocalFileCopyDriver(),
);
```

---

## Download a file

```dart
final repo = FileTaskRepository.instance;

final task = await repo.createDownloadTask(
  taskId: 'profile_photo_001',
  request: DownloadRequest(
    taskId: 'profile_photo_001',
    source: Uri.parse('https://cdn.example.com/photos/001.jpg'),
    localPath: '/data/user/0/com.example.app/files/001.jpg',
  ),
);

// Observe progress
repo.downloadTaskStream(taskId: task.taskId).listen((fileTask) {
  print('State: ${fileTask.state}, progress: ${fileTask.progress}');
});
```

---

## Upload a file

Using a custom driver (built-in drivers do not support upload to a remote server):

```dart
await TransferKitConfig.init(
  driver: MyHttpUploadDriver(apiToken: myToken),
);

final task = await repo.createUploadTask(
  taskId: 'document_upload_001',
  request: UploadRequest(
    taskId: 'document_upload_001',
    localPath: '/data/user/0/com.example.app/cache/doc.pdf',
    destinationPath: 'documents/user123/doc.pdf',
  ),
);
```

---

## Pause, resume, and cancel

```dart
// Only available if driver declares the capability
await repo.pauseTask('profile_photo_001');
await repo.resumeTask('profile_photo_001');
await repo.cancelTask('profile_photo_001');
```

Calling any of these on a driver that doesn't support them throws `UnsupportedCapabilityException`. Check first if needed:

```dart
final driver = TransferKitConfig.instance.driver;
if (driver.capabilities.supportsPause) {
  await repo.pauseTask(taskId);
}
```

---

## Implement a custom driver

```dart
class MyS3UploadDriver implements TransferDriver {
  MyS3UploadDriver({required String accessKey, required String secretKey})
      : _accessKey = accessKey,
        _secretKey = secretKey;

  final String _accessKey;
  final String _secretKey;

  @override
  TransferCapabilities get capabilities => const TransferCapabilities(
        supportsUpload: true,
        supportsCancel: true,
        supportsProgress: true,
      );

  @override
  Stream<TransferProgressEvent> upload(UploadRequest request) async* {
    // Sign the request using _accessKey / _secretKey
    // Open the file at request.localPath
    // Stream chunks to S3, yielding progress events
    yield TransferProgressUpdate(
      taskId: request.taskId,
      bytesTransferred: 512,
      totalBytes: 1024,
    );
    // ... more chunks ...
    yield TransferCompleted(
      taskId: request.taskId,
      remoteIdentifier: 'https://my-bucket.s3.amazonaws.com/key',
    );
  }

  @override
  Stream<TransferProgressEvent> download(DownloadRequest request) =>
      throw UnsupportedCapabilityException(
        'MyS3UploadDriver does not support download.',
        capability: 'supportsDownload',
      );

  @override
  Future<void> pause(String taskId) =>
      throw UnsupportedCapabilityException(
        'MyS3UploadDriver does not support pause.',
        capability: 'supportsPause',
      );

  @override
  Future<void> resume(String taskId) =>
      throw UnsupportedCapabilityException(
        'MyS3UploadDriver does not support resume.',
        capability: 'supportsResume',
      );

  @override
  Future<void> cancel(String taskId) async {
    // Cancel the in-flight S3 multipart upload
  }
}
```

---

## Implement a Firebase adapter (for existing Firebase users)

TransferKit 3.0.0 does not include a Firebase adapter. You can implement one:

```dart
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

  // pause / resume / cancel delegate to the Firebase UploadTask / DownloadTask
  // stored in a local map keyed by taskId ...

  String _tempPath(String taskId) =>
      '${Directory.systemTemp.path}/transfer_kit_$taskId';
}
```

---

## Writing tests with FakeTransferDriver

```dart
import 'package:flutter_test/flutter_test.dart';
import '../src/fake/fake_transfer_driver.dart'; // from test/ directory

void main() {
  test('task reaches completed state', () async {
    final driver = FakeTransferDriver(progressSteps: 3);
    await TransferKitConfig.init(driver: driver);

    final repo = FileTaskRepository.instance;
    final task = await repo.createDownloadTask(
      taskId: 'test_001',
      request: DownloadRequest(
        taskId: 'test_001',
        source: Uri.parse('fake://file.txt'),
      ),
    );

    final states = <FileTaskState>[];
    await repo.downloadTaskStream(taskId: task.taskId)
        .map((t) => t.state)
        .listen(states.add)
        .asFuture();

    expect(states, containsAllInOrder([
      FileTaskState.running,
      FileTaskState.completed,
    ]));
  });

  test('unsupported pause throws UnsupportedCapabilityException', () async {
    final driver = FakeTransferDriver(supportsPause: false);
    await TransferKitConfig.init(driver: driver);

    final repo = FileTaskRepository.instance;
    await repo.createDownloadTask(
      taskId: 'test_002',
      request: DownloadRequest(
        taskId: 'test_002',
        source: Uri.parse('fake://file.txt'),
      ),
    );

    expect(
      () => repo.pauseTask('test_002'),
      throwsA(isA<UnsupportedCapabilityException>()),
    );
  });
}
```
