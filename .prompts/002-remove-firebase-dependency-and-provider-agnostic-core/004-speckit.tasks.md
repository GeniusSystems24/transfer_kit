/speckit.tasks

Generate implementation tasks for removing Firebase handling and introducing a provider-agnostic transfer core.

## Task Group 1: Audit Firebase Coupling

- [ ] Search for all Firebase imports.
- [ ] List Firebase-specific files.
- [ ] List Firebase-specific public APIs.
- [ ] List Firebase-specific model fields or methods.
- [ ] Document migration impact.

Acceptance:
- Audit summary identifies every Firebase coupling point.

## Task Group 2: Generic Transfer Contracts

- [ ] Add `TransferDriver`.
- [ ] Add `TransferCapabilities`.
- [ ] Add `DownloadRequest`.
- [ ] Add `UploadRequest`.
- [ ] Add `TransferProgressEvent`.
- [ ] Add `TransferResult` if needed.

Acceptance:
- Core contracts compile.
- No Firebase import in new contracts.

## Task Group 3: Fake Drivers for Tests

- [ ] Add successful fake driver.
- [ ] Add failing fake driver.
- [ ] Add progress fake driver.
- [ ] Add unsupported capability fake driver.

Acceptance:
- Tests can run without Firebase.

## Task Group 4: Repository Refactor

- [ ] Refactor download flow to use `TransferDriver`.
- [ ] Refactor upload flow to use `TransferDriver`.
- [ ] Preserve task lifecycle behavior.
- [ ] Preserve cache integration.
- [ ] Preserve stream sharing concept through generic stream sharing.

Acceptance:
- Upload/download tests pass using fake driver.
- No direct Firebase dependency in core flow.

## Task Group 5: Remove Firebase Factory

- [ ] Remove or isolate `FirebaseStorageFactory`.
- [ ] Remove Firebase imports from core files.
- [ ] Remove Firebase-specific task methods.
- [ ] Remove Firebase dependencies from `pubspec.yaml` if no longer needed.

Acceptance:
- `flutter analyze` shows no unresolved Firebase references.
- Core package does not require Firebase initialization.

## Task Group 6: Capability Handling

- [ ] Implement behavior for unsupported pause/resume/cancel.
- [ ] Add tests for unsupported capability.
- [ ] Ensure behavior is documented.

Acceptance:
- Unsupported operations behave predictably.

## Task Group 7: Documentation and Migration

- [ ] Rewrite README overview.
- [ ] Update quick start.
- [ ] Add driver injection example.
- [ ] Add migration guide for Firebase users.
- [ ] Update CHANGELOG.md.
- [ ] Remove Firebase-only marketing claims.

## Task Group 8: Validation

- [ ] Run `dart format .`.
- [ ] Run `flutter analyze`.
- [ ] Run `flutter test`.
- [ ] Confirm no Firebase imports remain in core package.

Definition of Done:
- TransferKit core is provider-agnostic.
- Tests do not require Firebase.
- Docs explain the new architecture.
- Migration guide exists.
