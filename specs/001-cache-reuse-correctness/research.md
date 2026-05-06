# Phase 0 Research: Cache Reuse and Local Cache Correctness

**Feature**: 001-cache-reuse-correctness  
**Date**: 2026-05-07  
**Status**: Complete — all NEEDS CLARIFICATION resolved

---

## Decision 1: Cache Entry Storage Strategy

**Decision**: Extend the existing `FilePathAndURL` model with cache-specific fields (`cacheKey`, `createdAt`, `updatedAt`, `lastAccessedAt`, `expiresAt`) rather than introducing a new `CacheEntry` model.

**Rationale**: `FilePathAndURL` is already the repository's unit of storage in `FilePathAndURLRepository`. It uses a flexible `Map<String, dynamic> data` pattern where new fields are added as nullable tag-keyed entries — backward-compatible by design. Creating a parallel `CacheEntry` model would require migrating all existing code paths and every caller that constructs or reads `FilePathAndURL`. The `data`-map pattern already handles optional fields gracefully (missing keys → null values).

**Alternatives considered**:
- Dedicated `CacheEntry` model wrapping `FilePathAndURL` — cleaner domain separation, but would require a new repository and break all existing callers.
- Hive or Isar for the cache index — better query performance, but the spec assumption explicitly states GetStorage unless proven inadequate.

---

## Decision 2: Cache Key Derivation

**Decision**: When `cacheKey` is provided by the caller, use it as the input to `toHashName()` to derive the local file path; when not provided, use the full URL (existing behavior). Store the effective cache key in `FilePathAndURL.cacheKey`.

**Rationale**: The local file path is determined by `url.toHashName().toCachedPath()` (SHA-256 hash of URL + extension + cache directory). For callers supplying a stable `cacheKey`, we substitute the key as the hash input so the same logical file always maps to the same local path regardless of URL rotation. The `FilePathAndURLRepository` lookup uses `cacheKey` first (for entries that have one), falling back to URL for legacy entries.

**Alternatives considered**:
- Using the raw cache key as the filename — rejected because arbitrary strings are not safe filenames.
- Separate lookup map (key → path) — adds complexity with no benefit over a field on the existing model.

---

## Decision 3: SHA-256 Verification on Cache Hit

**Decision**: Reuse `FilePathAndURL.metadata?.sha256` (already computed by `MetadataExtractionService` when `autoExtractSha256 = true`) as the stored hash for FR-002 verification. No separate SHA-256 field is added to `FilePathAndURL`. Verification is skipped when `metadata?.sha256` is null (entries that pre-date the feature or where hash extraction was not enabled).

**Rationale**: `MediaMetadata.sha256` is already stored in the cache entry via `FilePathAndURLRepository` after every download when `autoExtractSha256` is enabled in `TransferKitConfig`. Adding a duplicate field would require double-computing and double-storing the hash. The existing `sha256` field in `MediaMetadata` fulfills FR-017 exactly.

**Verification logic location**: Inside `getCachedDownloadFilePathAndURL` in `FilePathAndURLRepository`, after the file existence check.

---

## Decision 4: Default Cache Storage Directory

**Decision**: Change the default cache directory from `applicationDocumentsDirectory/cached` to `applicationSupportDirectory/cached`, as required by FR-016 and the spec clarification. Make the directory overridable via `TransferKitConfig.init(cacheDirectory: path)`.

**Rationale**: The application support directory is hidden from users, survives app updates, and is cleared on uninstall — the correct location for a file cache. The current use of `applicationDocumentsDirectory` is a pre-existing inaccuracy that this feature explicitly corrects.

**Migration impact**: Existing cached files will appear as cache misses after this change. Document in CHANGELOG.md and README.md. Callers who want to retain old behavior can pass `cacheDirectory: (await getApplicationDocumentsDirectory()).path + '/cached'`.

**Implementation**: `AppDirectory.init()` receives an optional `cacheDirectory` override. If provided, that path is used. If null, `applicationSupportDirectory/cached` is the new default.

---

## Decision 5: Metadata Returned on Cache Hit (FR-019)

**Decision**: Add a `MediaMetadata? cachedMetadata` field (stored in `FileTask.data`) to `FileTask`. Populated when `FileTaskState.cached` is set in `FileTaskRepository.createDownloadTask` by reading `filePathAndUrl.metadata`. Callers access it via `task.cachedMetadata`.

**Rationale**: The spec requires metadata to be returned to the caller alongside the local file path on a cache hit. The `filePath` is already in `FileTask.filePath`. The `FileTask.filePathAndURL` computed getter constructs a fresh `FilePathAndURL` from `filePath` and `downloadUrl` — it does not read metadata from the repository. Therefore metadata must be explicitly stamped onto the `FileTask` at creation time when state is `cached`.

**Alternatives considered**:
- Caller queries `FilePathAndURLRepository.instance.getByUrl(url)?.metadata` — works, but is indirect and requires the caller to know to do this separate lookup.
- Adding `metadata` to `FileTask.filePathAndURL` — would require `filePathAndURL` to read from the repository, coupling a model getter to a repository singleton.

---

## Decision 6: Stale Entry Cleanup Strategy

**Decision**: When `getCachedDownloadFilePathAndURL` detects a stale entry (file missing from disk), immediately remove the entry from `FilePathAndURLRepository` before returning null. This keeps the index consistent without a separate repair pass.

**Rationale**: The stale detection already runs on every cache lookup. Performing the removal in-place means the index self-heals during normal operation. A separate `repairStaleEntries()` method is still provided for explicit cleanup, but normal use-case stale entries are cleared automatically.

---

## Decision 7: Forced Refresh Implementation

**Decision**: Add `forceRefresh: bool = false` to `createDownloadTask` in both `FirebaseFileRepository` and `FileTaskRepository`. When `true`: (1) skip the cache lookup, (2) if a matching index entry and local file exist, delete the file and remove the index entry, (3) proceed with a new download as if the file was never cached.

**Rationale**: Forced refresh is a first-class operation. Clearing the stale entry before downloading ensures the new download writes a fresh cache entry rather than finding an apparent conflict.

---

## Decision 8: Expiration Enforcement

**Decision**: `expiresAt` is optional (null = never expires). Checked in `getCachedDownloadFilePathAndURL` after the file existence check: if `expiresAt` is non-null and in the past, the entry is treated as a cache miss (entry removed, download triggered). A separate `clearExpiredEntries()` method performs bulk cleanup.

**Rationale**: Per spec assumption: "File expiration is optional and disabled by default; expiry is only enforced when `expiresAt` is explicitly set on an entry." The inline check ensures expired files are not silently served.

---

## Decision 9: Test Strategy

**Decision**: Write unit tests using `fake` implementations (no mocking framework added). Create `FakeFilePathAndURLRepository` (in-memory, no GetStorage) and use `dart:io` `Directory.systemTemp` for real filesystem operations in tests.

**Rationale**: The pubspec.yaml has no mock framework (`mockito`, `mocktail`) in dev_dependencies. Adding one would be the smallest-scope dev dependency change, but the `data`-map pattern used throughout TransferKit makes it straightforward to write fakes that inherit from the real classes. Using a real temp directory validates actual file existence checks without mocking `File`.

**Test files**:
- `test/cache/cache_correctness_test.dart` — main test file covering all FR-015 scenarios
- `test/cache/helpers/fake_file_path_and_url_repository.dart` — in-memory repository fake

---

## Pre-existing Gaps vs. Spec Requirements

| FR | Pre-existing Status | What Was Missing |
|----|--------------------|----|
| FR-001 | ✅ Implemented | — |
| FR-002 | ⚠️ Partial | SHA-256 verification step in cache lookup not wired up |
| FR-003 | ✅ Implemented | — |
| FR-004 | ❌ Missing | No `cacheKey` parameter in any API |
| FR-005 | ⚠️ Partial | Stale entry detected but NOT removed from index |
| FR-006 | ❌ Missing | No `forceRefresh` parameter |
| FR-007 | ❌ Missing | No `updatedAt` / `lastAccessedAt` timestamps on cache entries |
| FR-008 | ⚠️ Partial | `FilePathAndURL` missing `cacheKey`, timestamps, `expiresAt` |
| FR-009 | ⚠️ Partial | `clearCache(url)` deleted file but NOT index entry |
| FR-010 | ⚠️ Partial | `clearCacheForUrls` deleted files but NOT index entries |
| FR-011 | ❌ Missing | No expiry enforcement or cleanup method |
| FR-012 | ⚠️ Partial | Stale detection existed; index repair did not |
| FR-013 | ✅ Implemented | — |
| FR-014 | ✅ Implemented | `FileTaskState.cached` already exists |
| FR-015 | ❌ Missing | No test directory |
| FR-016 | ❌ Missing | Cache dir hardcoded to `applicationDocumentsDirectory/cached` |
| FR-017 | ⚠️ Partial | SHA-256 computed and stored; verification on cache hit not implemented |
| FR-018 | ✅ Implemented | `getDownloadTaskByUrl` deduplication in place |
| FR-019 | ⚠️ Partial | Metadata stored; not returned in cached `FileTask` |
