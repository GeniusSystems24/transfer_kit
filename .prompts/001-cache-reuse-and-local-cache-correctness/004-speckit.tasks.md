/speckit.tasks

Generate implementation tasks for cache reuse and local cache correctness.

## Task Group 1: Audit

- [ ] Inspect current cache-related methods and document behavior.
  - Files likely affected:
    - `lib/src/transfer_kit.dart`
    - `lib/src/repository/firebase_file_repository.dart`
    - `lib/src/repository/file_path_and_url_repository.dart`
    - `lib/src/core/extension/file_path_extension.dart`
  - Acceptance:
    - A short audit note exists in the implementation summary.
    - Cache hit/miss path is understood before code changes.

## Task Group 2: Cache Key Strategy

- [ ] Define cache key resolution.
  - Add a small internal helper if needed.
  - Support optional caller-provided cache key if approved.
  - Acceptance:
    - Same logical file resolves to the same cache key.
    - Unsafe raw path usage is avoided.

## Task Group 3: Cache Lookup Before Download

- [ ] Implement cache-first lookup before creating a new download task.
  - Acceptance:
    - Existing valid cached file avoids network download.
    - Returned task state is consistent.
    - Stream subscribers receive final cached state.

## Task Group 4: Stale Cache Repair

- [ ] Detect cache index entries whose local file is missing.
  - Acceptance:
    - Stale entry is removed or marked stale.
    - Download proceeds normally.
    - Regression test exists.

## Task Group 5: Forced Refresh

- [ ] Add or refine explicit force-refresh behavior.
  - Acceptance:
    - Cache is bypassed only when requested.
    - Previous cache is preserved if refresh fails, unless explicitly configured otherwise.

## Task Group 6: Cache Cleanup

- [ ] Implement safe single-file cleanup.
- [ ] Implement expired-entry cleanup if configured.
- [ ] Implement max-size cleanup if configured.
  - Acceptance:
    - Local files are deleted safely.
    - Remote files are never deleted.
    - Cache index remains consistent.

## Task Group 7: Tests

- [ ] Add test: cache hit avoids download.
- [ ] Add test: cache miss downloads.
- [ ] Add test: stale cache repairs and downloads.
- [ ] Add test: forced refresh bypasses cache.
- [ ] Add test: cleanup removes file and index.
- [ ] Add test: concurrent requests do not duplicate download.

## Task Group 8: Documentation

- [ ] Update README.md cache section.
- [ ] Update examples if needed.
- [ ] Update CHANGELOG.md.
- [ ] Add limitations for signed URLs and cache key strategy.

## Definition of Done

- `dart format .` passes.
- `flutter analyze` passes.
- `flutter test` passes.
- Cache behavior is documented.
- No unrelated Firebase-removal work is included in this task.
