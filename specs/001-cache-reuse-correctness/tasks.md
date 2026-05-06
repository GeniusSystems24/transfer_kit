# Tasks: Cache Reuse and Local Cache Correctness

**Input**: Design documents from `specs/001-cache-reuse-correctness/`
**Prerequisites**: [plan.md](plan.md) ✅, [spec.md](spec.md) ✅, [research.md](research.md) ✅, [data-model.md](data-model.md) ✅, [contracts/public-api.md](contracts/public-api.md) ✅

**Tests**: Included — FR-015 mandates regression tests covering all specified cache scenarios.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel with other [P] tasks in the same phase (different files, no blocking dependencies)
- **[Story]**: User story this task belongs to (US1–US5)
- All paths are relative to `packages/transfer_kit/`

---

## Phase 1: Setup

**Purpose**: Create the test infrastructure shared by all user story test tasks.

- [ ] T001 Create `test/cache/helpers/fake_file_path_and_url_repository.dart` — in-memory `FilePathAndURLRepository` subclass backed by `Set<FilePathAndURL>` with no GetStorage dependency; implement `addOrUpdate`, `remove`, `getByUrl`, `getByKey`, `getByPath`, and `getCachedDownloadFilePathAndURL` using real `dart:io` `File` checks against temp paths written by tests

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Data model and config extensions that EVERY user story implementation and test depends on.

**⚠️ CRITICAL**: No user story task can begin until all foundational tasks are complete and the package compiles cleanly.

- [ ] T002 [P] Update `lib/src/model/file_path_and_url.dart` — add 5 tag constants (`cacheKeyTag`, `createdAtTag`, `updatedAtTag`, `lastAccessedAtTag`, `expiresAtTag`); add corresponding getters and setters using the existing `data` map pattern (DateTime values stored as ISO-8601 strings); update `FilePathAndURL.url()` factory to accept `String? cacheKey` and `DateTime? expiresAt` — when `cacheKey` is non-null, derive `path` from `cacheKey.toHashName().toCachedPath()` instead of the URL; update `copyWith()` to include all 5 new optional params
- [ ] T003 [P] Update `lib/src/model/file_task.dart` — add `cachedMetadataTag = 'cachedMetadata'`; add `cachedMetadata: MediaMetadata?` getter (deserializes from `data` map) and setter (serializes via `value.toMap()`); update `FileTask.download()` constructor to accept optional `MediaMetadata? cachedMetadata` and store it; update `copyWith()` with `cachedMetadata` param
- [ ] T004 [P] Update `lib/src/core/file_management_config.dart` — add `String? _cacheDirectory` private field and `String? get cacheDirectory` getter; add `String? cacheDirectory` to `init()` named params and `_internal` constructor; add `'cacheDirectory': _cacheDirectory` to `toMap()`; pass `cacheDirectory` to `AppDirectory.init(cacheDirectory: cacheDirectory)`
- [ ] T005 [P] Update `lib/src/core/extension/file_path_extension.dart` — update `AppDirectory.init()` signature to `Future<AppDirectory> init({String? cacheDirectory})`; update `_getCachedDirectory()` to accept `{String? overridePath}` and use it when non-null, otherwise default to `'${(await getApplicationSupportDirectory()).path}/cached'` (changed from `applicationDocumentsDirectory`)

**Checkpoint**: Run `flutter analyze` — zero new errors. Package compiles. User story implementation can begin.

---

## Phase 3: User Story 1 — Cache Hit Reuse (Priority: P1) 🎯 MVP

**Goal**: A second request for the same file returns the cached local file immediately — zero network calls, `FileTaskState.cached`, and `cachedMetadata` populated.

**Independent Test**: Download a file once, clear the transport call log, request the same file again — assert `task.state == FileTaskState.cached`, `task.filePath` resolves to a real local file, and no transport calls were made.

### Implementation for User Story 1

- [ ] T006 [P] [US1] Update `lib/src/repository/file_path_and_url_repository.dart` — add `FilePathAndURL? getByKey(String cacheKey)` that returns the first entry where `entry.cacheKey == cacheKey`; update `getCachedDownloadFilePathAndURL()` signature to `Future<FilePathAndURL?> getCachedDownloadFilePathAndURL({required String url, String? cacheKey})`; implement lookup chain: try `getByKey(cacheKey)` first (when non-null), then `getByUrl(url)`; if file at `entry.path` does not exist call `remove(entry)` and return null; on hit update `lastAccessedAt = DateTime.now()` via `copyWith` and call `addOrUpdate()`; return updated entry
- [ ] T007 [US1] Update `lib/src/repository/file_task_repository.dart` — add `String? cacheKey` and `bool forceRefresh = false` to `createDownloadTask()` named params; pass `cacheKey` to `getCachedDownloadFilePathAndURL(url: url, cacheKey: cacheKey)`; on cache hit construct the `FileTask` with `state: FileTaskState.cached` and set `cachedMetadata: filePathAndUrl.metadata`; leave `forceRefresh` as a no-op stub for now (behavior added in US3)
- [ ] T008 [US1] Update `lib/src/repository/firebase_file_repository.dart` — add `String? cacheKey` and `bool forceRefresh = false` to `createDownloadTask()`; extract `cacheKey` from `filePathAndUrl.cacheKey` and pass both to `FileTaskRepository.instance.createDownloadTask(cacheKey: ..., forceRefresh: ...)`
- [ ] T009 [US1] Update `lib/src/transfer_kit.dart` — add `bool forceRefresh = false` to both `downloadTaskStream()` and `downloadTask()`; pass `forceRefresh` through to `repository.createDownloadTask()`; the `cacheKey` is already carried by `filePathAndUrl.cacheKey` and flows through the chain automatically

### Tests for User Story 1

- [ ] T010 [P] [US1] Add to `test/cache/cache_correctness_test.dart` — write `cache_hit_returns_cached_task` (second request returns `FileTaskState.cached`), `cache_hit_verifies_file_exists_on_disk` (existence check runs before reporting cached), `cached_task_emits_cached_state` (stream emits `cached` not `completed`)
- [ ] T011 [P] [US1] Add to `test/cache/cache_correctness_test.dart` — write `cached_metadata_returned_on_cache_hit` (`task.cachedMetadata` non-null with correct fields), `concurrent_requests_deduplicated` (two simultaneous first-time requests start exactly one download)

**Checkpoint**: `flutter test test/cache/` — all 5 US1 tests pass. Cache hit flow fully functional.

---

## Phase 4: User Story 2 — Stale Cache Detection and Recovery (Priority: P2)

**Goal**: When a cache index entry exists but the local file has been deleted, TransferKit detects it, removes the stale entry, and triggers a fresh download. An explicit repair method is also available.

**Independent Test**: Create a `FilePathAndURL` entry pointing to a temp file, delete the temp file, call `getCachedDownloadFilePathAndURL` — assert null returned and the index entry removed. Then call `repairStaleCacheEntries()` on a fresh set of stale entries and assert the count and clean index state.

### Implementation for User Story 2

- [ ] T012 [P] [US2] Update `lib/src/repository/file_path_and_url_repository.dart` — add `Future<int> repairStaleEntries()`: iterate `value.toList()`, remove index entries where `await File(entry.path).exists()` is false, batch the `remove()` calls, call `notifyListeners()` once, return the count removed; no remote file operations
- [ ] T013 [US2] Update `lib/src/transfer_kit.dart` — add `Future<int> repairStaleCacheEntries()` delegating to `FilePathAndURLRepository.instance.repairStaleEntries()`

### Tests for User Story 2

- [ ] T014 [P] [US2] Add to `test/cache/cache_correctness_test.dart` — write `stale_entry_treated_as_cache_miss` (file deleted → `getCachedDownloadFilePathAndURL` returns null), `stale_entry_removed_from_index` (index has no entry after stale detection), `repair_stale_entries` (repairStaleEntries count equals deleted-file count; index clean afterward)

**Checkpoint**: `flutter test test/cache/` — all US1 and US2 tests pass. Stale entries auto-repaired.

---

## Phase 5: User Story 3 — Forced Refresh (Priority: P3)

**Goal**: `forceRefresh: true` bypasses the cache, deletes any existing local file and index entry, initiates a network download, and the resulting task state is `completed` — never `cached`.

**Independent Test**: Create a valid cache entry with an existing local file, call `downloadTask(forceRefresh: true)` — assert the existing file was deleted, a download transport call was made, and `task.state == FileTaskState.completed`.

### Implementation for User Story 3

- [ ] T015 [US3] Update `lib/src/repository/file_task_repository.dart` — implement `forceRefresh` behavior in `createDownloadTask()`: when `forceRefresh == true`, look up any existing entry via `getByKey(cacheKey)` or `getByUrl(url)`; if found, delete `File(entry.path)` if it exists and call `FilePathAndURLRepository.instance.remove(entry)`; then skip the cache-hit branch entirely and proceed with a new download task; the resulting task must flow through `running` → `completed`, never emit `cached`

### Tests for User Story 3

- [ ] T016 [P] [US3] Add to `test/cache/cache_correctness_test.dart` — write `forced_refresh_always_downloads` (transport called even with valid cached file), `forced_refresh_replaces_cache_entry` (cache entry updated with fresh metadata after download completes), `forced_refresh_task_state_is_not_cached` (observed task state is `completed`, not `cached`)

**Checkpoint**: `flutter test test/cache/` — all US1, US2, and US3 tests pass. Forced refresh fully functional.

---

## Phase 6: User Story 4 — Cache Metadata and Index Reliability (Priority: P4)

**Goal**: Every successful download writes a complete cache entry with timestamps (`createdAt`, `updatedAt`). Cache lookups enforce expiry. SHA-256 verification runs when enabled. All required metadata fields are present and accurate.

**Independent Test**: Download a file with `autoExtractSha256: true` in config. Read the cache entry — assert `createdAt`, `updatedAt`, `metadata.sha256`, and mime type are all populated. Corrupt the local file content, run a second cache lookup — assert it triggers a re-download (hash mismatch).

### Implementation for User Story 4

- [ ] T017 [P] [US4] Update `lib/src/repository/file_path_and_url_repository.dart` — add expiry check to `getCachedDownloadFilePathAndURL()` before the file existence check: if `entry.expiresAt != null && entry.expiresAt!.isBefore(DateTime.now())`, call `remove(entry)` and return null; add SHA-256 verification after the existence check: when `TransferKitConfig.instance.autoExtractSha256 == true` and `entry.metadata?.sha256 != null`, read file bytes, compute `sha256.convert(bytes).toString()`, compare — mismatch calls `remove(entry)` and returns null; add `import 'package:crypto/crypto.dart'` if not already imported
- [ ] T018 [P] [US4] Update `lib/src/repository/firebase_file_repository.dart` — in the `onComplete` callback, after merging extracted metadata into `filePathAndURL`, set timestamps: `isNew = existingEntry == null`; apply `filePathAndURL = filePathAndURL.copyWith(createdAt: isNew ? now : existingEntry.createdAt, updatedAt: now)` before calling `FilePathAndURLRepository.instance.addOrUpdate(filePathAndURL)`
- [ ] T019 [US4] Update `lib/src/repository/file_path_and_url_repository.dart` — add `Future<int> clearExpiredEntries()`: collect entries where `expiresAt != null && expiresAt!.isBefore(DateTime.now())`, delete local files, remove index entries in batch, call `notifyListeners()` once, return count; then update `lib/src/transfer_kit.dart` — add `Future<int> clearExpiredCacheEntries()` delegating to `FilePathAndURLRepository.instance.clearExpiredEntries()`

### Tests for User Story 4

- [ ] T020 [P] [US4] Add to `test/cache/cache_correctness_test.dart` — write `last_accessed_at_updated_on_cache_hit` (`lastAccessedAt` changes between two cache hits), `updated_at_set_on_download_completion` (`updatedAt` non-null after download), `cache_entry_has_all_required_fields` (all 8 required fields from FR-008 present)
- [ ] T021 [P] [US4] Add to `test/cache/cache_correctness_test.dart` — write `clear_expired_entries` (only past-expiresAt entries removed), `non_expired_entries_untouched` (null or future expiresAt preserved), `sha256_mismatch_triggers_redownload` (corrupted file → hash mismatch → cache miss → re-download initiated)

**Checkpoint**: `flutter test test/cache/` — all US1–US4 tests pass. Cache index fully reliable.

---

## Phase 7: User Story 5 — Cache Cleanup Operations (Priority: P5)

**Goal**: Single-file deletion, multi-file deletion, expired-entry cleanup, and stale-entry repair all work correctly — removing only local files and index entries, never touching remote storage.

**Independent Test**: Populate 5 cache entries with known local files. Run `clearCache(url1)` — assert 1 file deleted and 1 index entry removed. Run `clearCacheForUrls({url2, url3})` — assert 2 more removed. Confirm remote transport mock received zero calls throughout.

### Implementation for User Story 5

- [ ] T022 [P] [US5] Update `lib/src/transfer_kit.dart` — fix `clearCache(String url)`: look up entry via `FilePathAndURLRepository.instance.getByUrl(url)`; if found, delete `File(entry.path)` if exists, then call `FilePathAndURLRepository.instance.remove(entry)`; if not found fall back to hash-based path deletion for backward compat; fix `clearCacheForUrls(Set<String> urls)` with the same pattern applied to each URL

### Tests for User Story 5

- [ ] T023 [P] [US5] Add to `test/cache/cache_correctness_test.dart` — write `delete_single_cache_entry` (file deleted + index entry removed via `clearCache`), `delete_set_of_cache_entries` (multiple entries removed via `clearCacheForUrls`), `cleanup_no_remote_operations` (assert transport mock has zero calls after any cleanup operation)

**Checkpoint**: `flutter test test/cache/` — all 20 regression tests pass. All 5 user stories functional.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, CHANGELOG, and final validation.

- [ ] T024 [P] Update `CHANGELOG.md` — add two `fix:` entries per plan.md Migration Notes: (1) `clearCache()`/`clearCacheForUrls()` now also removes index entries; migration: no action required unless callers explicitly depended on orphaned entries; (2) default cache directory changed from `applicationDocumentsDirectory/cached` to `applicationSupportDirectory/cached`; migration: pass `cacheDirectory: (await getApplicationDocumentsDirectory()).path + '/cached'` to `TransferKitConfig.init()` to preserve old behavior
- [ ] T025 [P] Update `README.md` — document new `cacheKey` parameter for signed URLs, `forceRefresh` parameter, `cachedMetadata` getter on `FileTask`, `clearExpiredCacheEntries()`, `repairStaleCacheEntries()`, `cacheDirectory` config option, and the default cache directory change
- [ ] T026 Verify `lib/transfer_kit.dart` barrel exports expose all new public surface: `clearExpiredCacheEntries`, `repairStaleCacheEntries`; since both methods are on the already-exported `TransferKit` class no new export lines should be needed — confirm and add if missing
- [ ] T027 Run `flutter analyze` in `packages/transfer_kit/` — zero new warnings or errors
- [ ] T028 Run `flutter test test/cache/` in `packages/transfer_kit/` — all 20 regression test scenarios pass

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
  └─► Phase 2 (Foundational) — BLOCKS all user stories
        ├─► Phase 3 (US1 — P1) 🎯 MVP
        │     └─► Phase 4 (US2 — P2) [depends on T006 for stale detection in getCachedDownloadFilePathAndURL]
        │     └─► Phase 5 (US3 — P3) [depends on T007 for forceRefresh stub in createDownloadTask]
        ├─► Phase 6 (US4 — P4) [independent — firebase_file_repository changes are orthogonal]
        └─► Phase 7 (US5 — P5) [independent — cleanup methods are standalone]
              └─► Phase 8 (Polish) — runs after all desired stories complete
```

### User Story Dependencies

| Story | Can Start After | Dependency Reason |
|-------|-----------------|-------------------|
| US1 (P1) | Phase 2 complete | No story dependencies |
| US2 (P2) | T006 complete | Stale entry removal in `getCachedDownloadFilePathAndURL` is implemented in T006 |
| US3 (P3) | T007 complete | `forceRefresh` stub in `file_task_repository` established in T007 |
| US4 (P4) | Phase 2 complete | `firebase_file_repository` timestamp changes are independent |
| US5 (P5) | Phase 2 complete | Cleanup methods are standalone |

### Within Each User Story

- Repository layer before task/facade layer (T006 → T007 → T008 → T009)
- Implementation tasks before test tasks (tests verify the implementation)
- Tests marked [P] can be written in parallel with later implementation tasks in the same story

### Parallel Opportunities

```
Phase 2 — all 4 foundational tasks [P] run simultaneously (different files)
Phase 3 — T006 [P] and T010/T011 test-writing [P] can start together
Phase 4 — T012 [P] and T014 test-writing [P] can start together
Phase 6 — T017 [P], T018 [P], T020 [P], T021 [P] all touch different files
Phase 8 — T024 [P] and T025 [P] run simultaneously
```

---

## Parallel Example: User Story 1

```
# Simultaneously (after Phase 2 complete):
T006: Add getByKey + update getCachedDownloadFilePathAndURL  ──┐
T010: Start writing US1 test scaffolding                      ──┘ (parallel)

# Sequentially after T006:
T007: Implement cacheKey + cachedMetadata in FileTaskRepository
T008: Wire cacheKey + forceRefresh through FirebaseFileRepository
T009: Add forceRefresh param to TransferKit.downloadTask/downloadTaskStream

# After T009 (all implementation done):
T010 + T011: Complete and run all US1 tests
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001)
2. Complete Phase 2: Foundational (T002–T005) ← **CRITICAL, blocks everything**
3. Complete Phase 3: US1 — Cache Hit Reuse (T006–T011)
4. **STOP and VALIDATE**: `flutter test test/cache/` — all 5 US1 tests must pass
5. Demo: zero network calls on second request; `task.state == FileTaskState.cached`

### Incremental Delivery

| Step | Tasks | Deliverable |
|------|-------|-------------|
| 1 | T001–T005 | Infrastructure + models ready |
| 2 | T006–T011 | Cache hits working — MVP |
| 3 | T012–T014 | Stale recovery working |
| 4 | T015–T016 | Forced refresh working |
| 5 | T017–T021 | Full metadata + expiry + SHA-256 |
| 6 | T022–T023 | Cleanup APIs complete |
| 7 | T024–T028 | CHANGELOG + README + final pass |

### Parallel Team Strategy (if applicable)

After Phase 2 completes:
- **Dev A**: US1 (T006–T011) → US2 (T012–T014) → US3 (T015–T016)
- **Dev B**: US4 (T017–T021) — independent firebase/repository changes
- **Dev C**: US5 (T022–T023) — independent cleanup methods
- **Everyone**: Polish phase together after all stories done

---

## Test Coverage Map (20 regression scenarios from FR-015)

| Test Name | Task | User Story | FR |
|-----------|------|------------|----|
| `cache_hit_returns_cached_task` | T010 | US1 | FR-001, FR-003 |
| `cache_hit_verifies_file_exists_on_disk` | T010 | US1 | FR-002 |
| `cached_task_emits_cached_state` | T010 | US1 | FR-014 |
| `cached_metadata_returned_on_cache_hit` | T011 | US1 | FR-019 |
| `concurrent_requests_deduplicated` | T011 | US1 | FR-018 |
| `stale_entry_treated_as_cache_miss` | T014 | US2 | FR-005 |
| `stale_entry_removed_from_index` | T014 | US2 | FR-005 |
| `repair_stale_entries` | T014 | US2 | FR-012 |
| `forced_refresh_always_downloads` | T016 | US3 | FR-006 |
| `forced_refresh_replaces_cache_entry` | T016 | US3 | FR-006 |
| `forced_refresh_task_state_is_not_cached` | T016 | US3 | FR-006 |
| `last_accessed_at_updated_on_cache_hit` | T020 | US4 | FR-007 |
| `updated_at_set_on_download_completion` | T020 | US4 | FR-007 |
| `cache_entry_has_all_required_fields` | T020 | US4 | FR-008 |
| `clear_expired_entries` | T021 | US4 | FR-011 |
| `non_expired_entries_untouched` | T021 | US4 | FR-011 |
| `sha256_mismatch_triggers_redownload` | T021 | US4 | FR-017 |
| `delete_single_cache_entry` | T023 | US5 | FR-009 |
| `delete_set_of_cache_entries` | T023 | US5 | FR-010 |
| `cleanup_no_remote_operations` | T023 | US5 | FR-013 |

---

## Notes

- Tasks marked [P] touch different files with no inter-task dependencies — safe to run in parallel
- `getCachedDownloadFilePathAndURL()` (T006 + T017) is the highest-risk method — it's the central cache validation gate covering existence, expiry, and SHA-256; review carefully before marking complete
- `FilePathAndURL.url()` factory update in T002 must preserve existing behavior exactly when `cacheKey` is null — all existing callers pass no `cacheKey` and must be unaffected
- Run `flutter analyze` after Phases 2 and 3 to catch type errors early; DateTime ISO-8601 serialization must round-trip cleanly through the `data` map
- Each phase ends with a test checkpoint — do not advance to the next phase until the checkpoint passes
