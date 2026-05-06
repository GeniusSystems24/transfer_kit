# Data Model: Cache Reuse and Local Cache Correctness

**Feature**: 001-cache-reuse-correctness  
**Date**: 2026-05-07

---

## Entity: FilePathAndURL (extended — serves as CacheEntry)

`FilePathAndURL` is the persisted cache entry stored in `FilePathAndURLRepository`. The following fields are **added** to the existing `data: Map<String, dynamic>` map. All new fields are nullable and backward-compatible (missing key = null value for existing entries).

### Existing Fields (unchanged)

| Field | Type | Tag | Description |
|-------|------|-----|-------------|
| `path` | `String` | `'path'` | Local file path on device |
| `url` | `String?` | `'url'` | Source download URL |
| `destinationPath` | `String?` | `'destinationPath'` | Firebase Storage path |
| `metadata` | `MediaMetadata?` | `'metadata'` | Extracted file metadata (image, video, audio, document); `metadata.sha256` serves as the stored hash for FR-017 verification |

### New Fields

| Field | Type | Tag | Default | Description |
|-------|------|-----|---------|-------------|
| `cacheKey` | `String?` | `'cacheKey'` | null (falls back to URL) | Explicit stable cache key; when provided, path is derived from `cacheKey.toHashName()` instead of URL |
| `createdAt` | `DateTime?` | `'createdAt'` | Set at first cache write | When the file was first downloaded and cached |
| `updatedAt` | `DateTime?` | `'updatedAt'` | Set at download completion or entry modification | When the cache entry was last updated |
| `lastAccessedAt` | `DateTime?` | `'lastAccessedAt'` | Set on every cache hit | When the cached file was last served to a caller |
| `expiresAt` | `DateTime?` | `'expiresAt'` | null (never expires) | Optional expiry; entry treated as cache miss after this time |

### Field Invariants

- `path` is always derived from `cacheKey ?? url` via `toHashName().toCachedPath()` — never stored as a caller-provided raw path for download tasks.
- `cacheKey` is stored as-is; the actual filename uses `cacheKey.toHashName()` (SHA-256 hash of cacheKey + extension).
- `metadata.sha256` (within the nested `MediaMetadata`) holds the file content hash when `autoExtractSha256 = true`. It is the gate for FR-017 verification.
- `expiresAt` has no default; the config's `cacheExpiration` duration is NOT automatically applied — callers must explicitly set `expiresAt` when creating a `FilePathAndURL` with an expiry requirement.
- `createdAt` is set once at first repository write; subsequent `addOrUpdate` calls set `updatedAt`, never `createdAt`.

### Serialization (Map keys)

```dart
static const String cacheKeyTag   = 'cacheKey';
static const String createdAtTag  = 'createdAt';    // ISO 8601 string
static const String updatedAtTag  = 'updatedAt';    // ISO 8601 string
static const String lastAccessedAtTag = 'lastAccessedAt'; // ISO 8601 string
static const String expiresAtTag  = 'expiresAt';    // ISO 8601 string
```

---

## Entity: FileTask (extended — metadata surface)

`FileTask` gains a `cachedMetadata` field stamped at task creation when state is `cached`. This avoids forcing callers to perform a separate repository lookup to retrieve file metadata on cache hit.

### New Field

| Field | Type | Tag | Description |
|-------|------|-----|-------------|
| `cachedMetadata` | `MediaMetadata?` | `'cachedMetadata'` | File metadata read from the cache entry at the time the cached task was created; null for non-cached tasks or tasks where no metadata was extracted |

### Population Rule

`cachedMetadata` is populated in `FileTaskRepository.createDownloadTask` exactly when:
1. A `FilePathAndURL` is found in `FilePathAndURLRepository` (cache hit).
2. The file passes existence (and optionally SHA-256) verification.
3. A `FileTask` with `FileTaskState.cached` is created — `cachedMetadata = filePathAndUrl.metadata` is written into the task's `data` map.

For tasks with any other state, `cachedMetadata` is null.

---

## Entity: CacheKey (logical — no new class)

A `CacheKey` is not a separate class. It is a `String` value:

- **Default**: the full source URL (`url`) — used as input to `toHashName()`.
- **Explicit**: caller-provided string passed as `cacheKey` to `FilePathAndURL.url()` — used instead of URL as input to `toHashName()`.

The resulting local path is always: `cacheKey.toHashName().toCachedPath()` or `url.toHashName().toCachedPath()`.

Repository lookup order when `cacheKey` is present:
1. `getByKey(cacheKey)` — finds entries where `data['cacheKey'] == cacheKey`.
2. If not found, `getByUrl(url)` — legacy fallback for entries without an explicit key.

---

## Entity: CacheIndex (logical — FilePathAndURLRepository)

`FilePathAndURLRepository` is the cache index. It stores a `Set<FilePathAndURL>` in GetStorage under key `'file_path_url'`.

**Consistency invariants** (enforced by new logic):
- No entry in the index references a file that does not exist on disk — stale entries are removed during cache lookup or explicit repair.
- No entry with an `expiresAt` in the past is served as a cache hit — expired entries are removed during lookup or explicit cleanup.
- Every download completion writes `createdAt` (first time) and `updatedAt`.
- Every cache hit writes `lastAccessedAt`.

**New methods added** to `FilePathAndURLRepository`:

| Method | Signature | Description |
|--------|-----------|-------------|
| `getByKey` | `FilePathAndURL? getByKey(String cacheKey)` | Lookup by explicit cache key |
| `getCachedDownloadFilePathAndURL` (updated) | `Future<FilePathAndURL?> getCachedDownloadFilePathAndURL({required String url, String? cacheKey})` | Adds stale removal, expiry check, SHA-256 verification, `lastAccessedAt` update |
| `clearExpiredEntries` | `Future<int> clearExpiredEntries()` | Deletes local files and index entries where `expiresAt` is past |
| `repairStaleEntries` | `Future<int> repairStaleEntries()` | Removes index entries where the local file is missing (no remote deletions) |

---

## Entity: TransferKitConfig (extended)

### New Configuration Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `cacheDirectory` | `String?` | `null` → `applicationSupportDirectory/cached` | Override the directory where downloaded files are cached |
| `enableSha256Verification` | — | — | Not a new field — reuses existing `autoExtractSha256: bool` (default `false`) as the gate for FR-017 |

The `cacheDirectory` parameter is added to `TransferKitConfig.init()` and passed to `AppDirectory.init()`. When null, the new default is `applicationSupportDirectory/cached` (changed from the previous `applicationDocumentsDirectory/cached`).

---

## State Transitions (cache-related)

```
[No cache entry]
      │
      ▼ First download requested
[running] ──► [completed]  ← file saved to disk, cache entry written (createdAt, updatedAt set)
                           ← metadata extracted and merged into entry
                           ← if autoExtractSha256: sha256 computed and stored

[Cache entry exists]
      │
      ▼ Subsequent request (no forceRefresh)
      │── File exists & valid ──► [cached]  ← lastAccessedAt updated, cachedMetadata populated in FileTask
      │── File missing (stale)  ──► entry removed ──► [running] ──► [completed]
      │── expiresAt in past     ──► entry removed ──► [running] ──► [completed]
      └── sha256 mismatch       ──► entry removed ──► [running] ──► [completed]

[forceRefresh = true]
      │
      ▼ Request with forceRefresh
      ── Existing file deleted, entry removed ──► [running] ──► [completed]
```

---

## Affected Files Summary

| File | Change Type | What Changes |
|------|-------------|-------------|
| `lib/src/model/file_path_and_url.dart` | Modified | Add 5 new nullable fields with tags; update `copyWith`, `fromMap`/`toMap` |
| `lib/src/model/file_task.dart` | Modified | Add `cachedMetadata: MediaMetadata?` field and tag; update `FileTask.download` constructor, `copyWith` |
| `lib/src/core/file_management_config.dart` | Modified | Add `cacheDirectory: String?` parameter to `init()` and `_internal` |
| `lib/src/core/extension/file_path_extension.dart` | Modified | `AppDirectory.init()` accepts `cacheDirectory`; default changes to `applicationSupportDirectory/cached` |
| `lib/src/repository/file_path_and_url_repository.dart` | Modified | Add `getByKey`, update `getCachedDownloadFilePathAndURL`, add `clearExpiredEntries`, `repairStaleEntries` |
| `lib/src/repository/firebase_file_repository.dart` | Modified | Set `createdAt`/`updatedAt` on download completion; pass `cacheKey` and `forceRefresh` |
| `lib/src/repository/file_task_repository.dart` | Modified | Accept `cacheKey` and `forceRefresh` in `createDownloadTask`; populate `cachedMetadata` on cache hit |
| `lib/src/transfer_kit.dart` | Modified | Update `clearCache`/`clearCacheForUrls` to remove index entries; add `clearExpiredCacheEntries()`, `repairStaleCacheEntries()` |
| `lib/transfer_kit.dart` | Modified | Export new public methods |
| `test/cache/cache_correctness_test.dart` | Created | Regression tests for all FR-015 scenarios |
| `test/cache/helpers/fake_file_path_and_url_repository.dart` | Created | In-memory fake for testing |
