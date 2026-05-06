/speckit.plan

Create a technical implementation plan to remove Firebase handling and introduce a provider-agnostic TransferKit core.

## Tech Stack

- Flutter / Dart
- Existing TransferKit package structure
- Existing task models where practical
- `flutter_test`
- No Firebase dependencies in the core package after this task

## Architecture Direction

Replace Firebase-specific implementation with provider interfaces.

Recommended core abstractions:

```dart
abstract interface class TransferDriver {
  TransferCapabilities get capabilities;

  Stream<TransferProgressEvent> download(DownloadRequest request);

  Stream<TransferProgressEvent> upload(UploadRequest request);

  Future<bool> pause(String taskId);

  Future<bool> resume(String taskId);

  Future<bool> cancel(String taskId);
}
```

```dart
class TransferCapabilities {
  final bool supportsUpload;
  final bool supportsDownload;
  final bool supportsPause;
  final bool supportsResume;
  final bool supportsCancel;
  final bool supportsProgress;
  final bool supportsBackgroundTransfer;
}
```

```dart
class DownloadRequest {
  final String taskId;
  final Uri source;
  final String? cacheKey;
  final String? localPath;
  final Map<String, Object?> metadata;
}
```

```dart
class UploadRequest {
  final String taskId;
  final String localPath;
  final Uri? destination;
  final String? destinationPath;
  final Map<String, Object?> metadata;
}
```

## Implementation Phases

### Phase 1: Audit Firebase coupling

- Search all imports of Firebase packages.
- List all classes coupled to Firebase types.
- List public APIs that expose Firebase assumptions.
- Identify which files must change.

### Phase 2: Introduce generic transfer contracts

- Add generic request/result/progress classes.
- Add `TransferDriver`.
- Add `TransferCapabilities`.
- Add fake driver for tests.
- Do not remove Firebase code yet.

### Phase 3: Redirect repository logic through driver

- Update upload/download orchestration to use `TransferDriver`.
- Keep task lifecycle unchanged.
- Keep stream sharing behavior through generic transfer streams.
- Map provider progress events to `FileTask`.

### Phase 4: Remove Firebase-specific factory

- Remove or deprecate Firebase-specific task factory.
- Remove direct Firebase imports from core.
- Delete Firebase-specific references from task model if present.
- Ensure tests use fake drivers.

### Phase 5: Built-in default driver

Decide and implement one of:

Option A:
- No default network provider.
- User must inject a driver.

Option B:
- Built-in HTTP download driver only.
- Upload requires custom driver.

Option C:
- Built-in local/fake driver for local transfer/testing only.

### Phase 6: Migration and docs

- Rewrite README identity from Firebase Storage solution to provider-agnostic transfer toolkit.
- Add migration guide from Firebase-coupled version.
- Update CHANGELOG.md.
- Remove or mark Firebase examples as legacy.

## Public API Strategy

Prefer additive compatibility:

- Keep `TransferKit()` entry point.
- Add config option for driver injection.
- Keep existing task control methods.
- Avoid exposing provider internals.

Example:

```dart
await TransferKitConfig.init(
  transferDriver: MyTransferDriver(),
);
```

Or:

```dart
final transferKit = TransferKit(driver: MyTransferDriver());
```

## Testing Strategy

Add fake providers:

1. `FakeSuccessfulTransferDriver`
2. `FakeFailingTransferDriver`
3. `FakeProgressTransferDriver`
4. `FakePauseResumeTransferDriver`
5. `FakeUnsupportedCapabilityDriver`

Test:
- download success,
- upload success,
- progress mapping,
- pause unsupported,
- resume unsupported,
- cancel unsupported,
- failure mapping,
- retry behavior,
- cache integration without Firebase.

## Risks

- Removing Firebase is likely breaking.
- README and examples must be rewritten.
- Existing users may need migration.
- Background transfer behavior may become provider-dependent.
- Some Firebase-specific features may not have generic equivalents.

## Rollback Strategy

- Introduce generic driver first while Firebase code still exists.
- Move one path at a time.
- Keep tests green after each phase.
- Remove Firebase only after generic driver tests pass.
