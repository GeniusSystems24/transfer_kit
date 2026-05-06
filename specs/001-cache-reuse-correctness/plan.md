# Implementation Plan: Cache Reuse and Local Cache Correctness

**Branch**: `001-cache-reuse-correctness` | **Date**: 2026-05-07 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `specs/001-cache-reuse-correctness/spec.md`

---

## Summary

Strengthen TransferKit's cache layer so that downloaded files are served from local storage reliably — never re-downloaded unless the cache entry is missing, invalid, expired, or explicitly refreshed. The plan adds explicit cache keys, cache entry timestamps, stale-entry cleanup, SHA-256 verification, forced refresh, configurable cache directory, metadata on cached tasks, and comprehensive regression tests. All changes are additive to public APIs (new optional parameters and new methods). Two behavior corrections are documented: `clearCache` now also removes index entries, and the default cache directory changes from `applicationDocumentsDirectory/cached` to `applicationSupportDirectory/cached`.

---

## Technical Context

**Language/Version**: Dart ≥3.10.0, Flutter ≥3.0.0  
**Primary Dependencies**: get_storage (cache index), path_provider (directory paths), crypto (SHA-256 hash), firebase_storage (download transport)  
**Storage**: GetStorage for cache index (`FilePathAndURLRepository`); local filesystem for cached files  
**Testing**: flutter_test; fake in-memory repository; dart:io temp directory for filesystem tests  
**Target Platform**: iOS and Android (Flutter mobile library package)  
**Project Type**: Flutter/Dart library package  
**Performance Goals**: Cache hit delivered in <200ms from request to file path (SC-007)  
**Constraints**: Zero breaking changes to existing API signatures; no remote file deletions from any cache operation; SHA-256 verification only when `autoExtractSha256 = true`  
**Scale/Scope**: Single-device local cache; max cache size enforcement deferred per spec assumption

---

## Constitution Check

*GATE: Must pass before implementation. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Public Package Stability | ✅ Pass | All changes add optional parameters; no existing signatures removed or renamed |
| II. Correct Transfer Lifecycle | ✅ Pass | `cached` state already exists and is correct; `forceRefresh` transitions through `running` → `completed`, never emits `cached` |
| III. Single Source of Truth | ✅ Pass | `FilePathAndURLRepository` remains the single cache index; task state flows through `FileTaskRepository` as before |
| IV. Stream Sharing and Resource Safety | ✅ Pass | No stream changes; FR-018 deduplication already implemented and preserved |
| V. Cache Correctness | ✅ Pass | Core goal of this feature — all gaps being fixed |
| VI. Firebase Storage Integration Boundary | ✅ Pass | No Firebase API surface changes; Firebase Storage errors remain typed |
| VII. Background Transfer Honesty | ✅ Pass | No background behavior changes |
| VIII. Metadata Extraction Safety | ✅ Pass | SHA-256 and waveform remain opt-in; metadata extraction failure does NOT fail the cache write (FR-019) |
| IX. Error Handling and Logging | ✅ Pass | No sensitive URL/token data logged; existing typed exception chain preserved |
| X. Performance and Memory Efficiency | ✅ Pass | Cache hit is O(1) map lookup; SHA-256 verification is opt-in and runs only on cached files |
| XI. Testing Requirements | ✅ Pass | Regression tests are required (FR-015) and fully planned |
| XII. Documentation and Release Discipline | ✅ Pass | README and CHANGELOG updates required and tasked |

No violations found. No complexity table needed.

---

## Project Structure

### Documentation (this feature)

```text
specs/001-cache-reuse-correctness/
├── plan.md              ← This file
├── research.md          ← Phase 0: all decisions and gap analysis
├── data-model.md        ← Phase 1: entity fields and state transitions
├── quickstart.md        ← Phase 1: usage guide for new features
├── contracts/
│   └── public-api.md   ← Phase 1: full API contract with backward-compat matrix
└── tasks.md             ← Phase 2 output (created by /speckit-tasks)
```

### Source Code (affected files only)

```text
lib/
├── transfer_kit.dart                           ← Export new public methods
└── src/
    ├── transfer_kit.dart                       ← Add forceRefresh param; add clearExpiredCacheEntries(), repairStaleCacheEntries(); fix clearCache/clearCacheForUrls
    ├── core/
    │   └── file_management_config.dart         ← Add cacheDirectory param to init()
    ├── core/extension/
    │   └── file_path_extension.dart            ← AppDirectory.init() accepts cacheDirectory; default → applicationSupportDirectory/cached
    ├── model/
    │   ├── file_path_and_url.dart              ← Add cacheKey, createdAt, updatedAt, lastAccessedAt, expiresAt fields + tags
    │   └── file_task.dart                      ← Add cachedMetadata field + tag; update FileTask.download() and copyWith()
    └── repository/
        ├── file_path_and_url_repository.dart   ← Add getByKey(); update getCachedDownloadFilePathAndURL(); add clearExpiredEntries(), repairStaleEntries()
        ├── firebase_file_repository.dart       ← Set createdAt/updatedAt on download completion; pass cacheKey and forceRefresh
        └── file_task_repository.dart           ← Accept cacheKey and forceRefresh in createDownloadTask(); populate cachedMetadata on cache hit

test/
└── cache/
    ├── cache_correctness_test.dart             ← Regression tests for FR-015
    └── helpers/
        └── fake_file_path_and_url_repository.dart  ← In-memory fake for tests
```

---

## Implementation: File-by-File Changes

### File 1: `lib/src/model/file_path_and_url.dart`

**What changes**: Add 5 new nullable fields using the existing `data` map pattern.

**New static const tags** (add alongside existing tags):
```dart
static const String cacheKeyTag       = 'cacheKey';
static const String createdAtTag      = 'createdAt';
static const String updatedAtTag      = 'updatedAt';
static const String lastAccessedAtTag = 'lastAccessedAt';
static const String expiresAtTag      = 'expiresAt';
```

**New getters/setters** (add alongside existing ones):
```dart
String? get cacheKey => data.getString(cacheKeyTag);
set cacheKey(String? value) => data[cacheKeyTag] = value;

DateTime? get createdAt => data.getDateTime(createdAtTag);
set createdAt(DateTime? value) => data[createdAtTag] = value?.toIso8601String();

DateTime? get updatedAt => data.getDateTime(updatedAtTag);
set updatedAt(DateTime? value) => data[updatedAtTag] = value?.toIso8601String();

DateTime? get lastAccessedAt => data.getDateTime(lastAccessedAtTag);
set lastAccessedAt(DateTime? value) =>
    data[lastAccessedAtTag] = value?.toIso8601String();

DateTime? get expiresAt => data.getDateTime(expiresAtTag);
set expiresAt(DateTime? value) => data[expiresAtTag] = value?.toIso8601String();
```

**Update `FilePathAndURL.url()` factory**:
- Add `String? cacheKey` and `DateTime? expiresAt` parameters.
- When `cacheKey != null`: set `pathTag` to `cacheKey.toHashName().toCachedPath()` and store `cacheKey` in `data[cacheKeyTag]`.
- When `cacheKey == null`: path remains `url.toHashName().toCachedPath()` (existing behavior).
- Store `expiresAt` if provided.

**Update `copyWith()`**: Add all 5 new optional parameters.

**No changes** to `FilePathAndURL.local()`, `fromMap()`, `toMap()`, equality, or `update()`.

---

### File 2: `lib/src/model/file_task.dart`

**What changes**: Add `cachedMetadata` field to carry file metadata from cache entries to callers.

**New static const tag** (add alongside existing tags):
```dart
static const String cachedMetadataTag = 'cachedMetadata';
```

**New getter/setter**:
```dart
MediaMetadata? get cachedMetadata {
  final map = data[cachedMetadataTag] as Map<String, dynamic>?;
  return map != null ? MediaMetadata.fromMap(map) : null;
}
set cachedMetadata(MediaMetadata? value) {
  if (value != null) {
    data[cachedMetadataTag] = value.toMap();
  } else {
    data.remove(cachedMetadataTag);
  }
}
```

**Update `FileTask.download()` constructor**: Add optional `MediaMetadata? cachedMetadata` parameter; include `cachedMetadataTag` in data map when non-null.

**Update `copyWith()`**: Add optional `MediaMetadata? cachedMetadata` parameter.

**No changes** to `FileTask.upload()`, `FileTask.fromTask()`, `FileTask.fromMap()`, lifecycle state logic, or Firebase task handling.

---

### File 3: `lib/src/core/extension/file_path_extension.dart`

**What changes**: `AppDirectory.init()` accepts an optional `cacheDirectory` override; default changes to `applicationSupportDirectory/cached`.

**Update `AppDirectory.init()`**:
```dart
static Future<AppDirectory> init({String? cacheDirectory}) async {
  if (isInitialized) return instance;
  instance = AppDirectory._();
  await instance._getApplicationDocumentsDirectory();
  await instance._getApplicationSupportDirectory();
  await instance._getRootDirectory();
  await instance._getTemporaryDirectory();
  await instance._getCachedDirectory(overridePath: cacheDirectory);
  await instance._getThumbDirectory();
  isInitialized = true;
  return instance;
}
```

**Update `_getCachedDirectory()`**:
```dart
Future<void> _getCachedDirectory({String? overridePath}) async {
  if (cachedDir != null) return;
  final path = overridePath ??
      '${(await _getApplicationSupportDirectory()).path}/cached';
  cachedDir = Directory(path);
  if (!cachedDir!.existsSync()) {
    cachedDir!.createSync(recursive: true);
  }
}
```

---

### File 4: `lib/src/core/file_management_config.dart`

**What changes**: Add `cacheDirectory` parameter to `init()`.

**New private field**:
```dart
String? _cacheDirectory;
String? get cacheDirectory => _cacheDirectory;
```

**Update `init()`**: Add `String? cacheDirectory` parameter; assign to `_cacheDirectory`; pass to `AppDirectory.init(cacheDirectory: cacheDirectory)`.

**Update `toMap()`**: Add `'cacheDirectory': _cacheDirectory`.

---

### File 5: `lib/src/repository/file_path_and_url_repository.dart`

**What changes**: New lookup method; updated cache check with stale removal, expiry, SHA-256 verification, and `lastAccessedAt`; new cleanup methods.

**Add `getByKey()`**:
```dart
FilePathAndURL? getByKey(String cacheKey) =>
    value.firstWhereOrNull((e) => e.cacheKey == cacheKey);
```

**Replace `getCachedDownloadFilePathAndURL()`**:
```dart
Future<FilePathAndURL?> getCachedDownloadFilePathAndURL({
  required String url,
  String? cacheKey,
}) async {
  // 1. Lookup: prefer cacheKey, fall back to URL
  final entry = (cacheKey != null ? getByKey(cacheKey) : null) ?? getByUrl(url);
  if (entry == null) return null;

  // 2. Expiry check
  if (entry.expiresAt != null && entry.expiresAt!.isBefore(DateTime.now())) {
    remove(entry);
    return null;
  }

  // 3. File existence check
  if (!await File(entry.path).exists()) {
    remove(entry);
    return null;
  }

  // 4. Optional SHA-256 verification
  if (TransferKitConfig.instance.autoExtractSha256) {
    final storedHash = entry.metadata?.sha256;
    if (storedHash != null) {
      final fileBytes = await File(entry.path).readAsBytes();
      final computedHash = sha256.convert(fileBytes).toString();
      if (computedHash != storedHash) {
        remove(entry);
        return null;
      }
    }
  }

  // 5. Update lastAccessedAt
  final updated = entry.copyWith(lastAccessedAt: DateTime.now());
  addOrUpdate(updated);

  return updated;
}
```

**Add `clearExpiredEntries()`**:
```dart
Future<int> clearExpiredEntries() async {
  final now = DateTime.now();
  final expired = value
      .where((e) => e.expiresAt != null && e.expiresAt!.isBefore(now))
      .toList();
  for (final entry in expired) {
    final file = File(entry.path);
    if (await file.exists()) await file.delete();
    remove(entry, notify: false);
  }
  if (expired.isNotEmpty) notifyListeners();
  return expired.length;
}
```

**Add `repairStaleEntries()`**:
```dart
Future<int> repairStaleEntries() async {
  final stale = <FilePathAndURL>[];
  for (final entry in value.toList()) {
    if (!await File(entry.path).exists()) {
      stale.add(entry);
    }
  }
  for (final entry in stale) {
    remove(entry, notify: false);
  }
  if (stale.isNotEmpty) notifyListeners();
  return stale.length;
}
```

**Required import**: `import 'package:crypto/crypto.dart';` (already in pubspec, needed here for SHA-256 verification).

---

### File 6: `lib/src/repository/firebase_file_repository.dart`

**What changes**: Set `createdAt`/`updatedAt` when writing cache entry on download completion; pass `forceRefresh` to `FileTaskRepository.createDownloadTask()`.

**Update `createDownloadTask()`**: Add `bool forceRefresh = false`; pass to `FileTaskRepository.instance.createDownloadTask(forceRefresh: forceRefresh)`.

**Update `downloadTaskStream.onComplete` callback**:
```dart
onComplete: (updatedTask) async {
  final existingFilePathAndUrl = FilePathAndURLRepository.instance
      .getByUrl(updatedTask.downloadUrl ?? '');
  var filePathAndURL = updatedTask.filePathAndURL;

  final extractedMetadata = await MetadataExtractionService()
      .extractMetadata(
        File(updatedTask.filePath),
        existingMetadata: existingFilePathAndUrl?.metadata ?? filePathAndURL.metadata,
      );
  filePathAndURL = filePathAndURL.copyWithMergedMetadata(extractedMetadata);

  // Set timestamps
  final now = DateTime.now();
  final isNew = existingFilePathAndUrl == null;
  filePathAndURL = filePathAndURL.copyWith(
    createdAt: isNew ? now : existingFilePathAndUrl.createdAt,
    updatedAt: now,
  );

  FilePathAndURLRepository.instance.addOrUpdate(filePathAndURL);
  FirebaseStorageFactory.clearCompletedTasks();
},
```

---

### File 7: `lib/src/repository/file_task_repository.dart`

**What changes**: `createDownloadTask()` accepts `cacheKey` and `forceRefresh`; populates `cachedMetadata` on cache hit; handles forced refresh by removing existing file/entry.

**Update `createDownloadTask()` signature**:
```dart
Future<FileTask> createDownloadTask({
  required String taskId,
  required String url,
  required FileGroupInfo group,
  bool autoStart = true,
  String? cacheKey,       // NEW
  bool forceRefresh = false, // NEW
}) async
```

**When `forceRefresh = true`**: Before the cache lookup, check if an existing entry exists; if so, delete the local file and remove from repository.

**On cache hit** (when `filePathAndUrl != null`): Populate `cachedMetadata` in the returned `FileTask`:
```dart
final newTask = FileTask.download(
  id: taskId,
  downloadUrl: filePathAndUrl.url!,
  group: group,
  state: FileTaskState.cached,
  progress: FileProgress(
    bytesTransferred: filePathAndUrl.file.lengthSync(),
    totalBytes: filePathAndUrl.file.lengthSync(),
  ),
  cachedMetadata: filePathAndUrl.metadata,  // NEW
);
```

**For path derivation**: When `cacheKey` is provided, `FileTask.download()` must use the cacheKey-derived path. Since `FileTask.download()` currently hardcodes `downloadUrl.toHashName().toCachedPath()` as `filePath`, we need to pass the resolved `filePath` explicitly when a `cacheKey` is used. Add an optional `filePath` parameter to `FileTask.download()`, or compute the path in `createDownloadTask` and pass it.

---

### File 8: `lib/src/transfer_kit.dart`

**What changes**: Fix `clearCache`/`clearCacheForUrls` to remove index entries; add `clearExpiredCacheEntries()` and `repairStaleCacheEntries()`; propagate `forceRefresh` to repository calls.

**Fix `clearCache()`**:
```dart
Future<void> clearCache(String url) async {
  final entry = FilePathAndURLRepository.instance.getByUrl(url);
  if (entry != null) {
    final file = File(entry.path);
    if (await file.exists()) await file.delete();
    FilePathAndURLRepository.instance.remove(entry);
  } else {
    // Legacy fallback: hash-based path
    final localPath = url.toHashName().toCachedPath();
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }
}
```

**Fix `clearCacheForUrls()`**: Apply the same pattern for each URL in the set.

**Add `clearExpiredCacheEntries()`**:
```dart
Future<int> clearExpiredCacheEntries() =>
    FilePathAndURLRepository.instance.clearExpiredEntries();
```

**Add `repairStaleCacheEntries()`**:
```dart
Future<int> repairStaleCacheEntries() =>
    FilePathAndURLRepository.instance.repairStaleEntries();
```

**Update `downloadTaskStream()` and `downloadTask()`**: Add `bool forceRefresh = false`; pass to `repository.createDownloadTask()`.

---

### File 9: `lib/transfer_kit.dart` (public barrel)

Add exports for the two new public methods on `TransferKit`. Since both methods are on the `TransferKit` class itself (already exported), no new export lines are needed — the methods are accessible through the existing class export.

If `FilePathAndURL` is not already exported (check barrel): ensure `FilePathAndURL.url(cacheKey:, expiresAt:)` constructor changes are accessible. No new export file needed.

---

### File 10: `test/cache/helpers/fake_file_path_and_url_repository.dart`

An in-memory implementation of `FilePathAndURLRepository` for unit tests. Stores entries in a `Set<FilePathAndURL>` without GetStorage or filesystem dependencies.

Key behaviors to replicate from the real repository:
- `addOrUpdate(entry)` — update if same hash, add if new
- `remove(entry)` — remove by hash equality
- `getByUrl(url)`, `getByKey(key)`, `getByPath(path)` — set lookups
- `getCachedDownloadFilePathAndURL({url, cacheKey})` — uses a real file check (test temp files)
- No GetStorage calls; no notifications (or use a simple `ValueNotifier<Set<>>`)

---

### File 11: `test/cache/cache_correctness_test.dart`

Regression tests covering all FR-015 scenarios:

| Test | FR | Scenario |
|------|----|---------|
| `cache_hit_returns_cached_task` | FR-001, FR-003, FR-014 | Second request returns `FileTaskState.cached` with no transport call |
| `cache_hit_verifies_file_exists_on_disk` | FR-002 | File existence check before reporting cached |
| `stale_entry_treated_as_cache_miss` | FR-005 | File deleted from disk → entry removed → re-download |
| `stale_entry_removed_from_index` | FR-005, FR-012 | Index entry absent after stale detection |
| `forced_refresh_always_downloads` | FR-006 | `forceRefresh: true` → transport called even with cached file |
| `forced_refresh_replaces_cache_entry` | FR-006 | Cache entry updated after forced refresh |
| `forced_refresh_task_state_is_not_cached` | FR-006 | Task state is `completed`, never `cached`, during forced refresh |
| `last_accessed_at_updated_on_cache_hit` | FR-007 | `lastAccessedAt` timestamp changes after serving from cache |
| `updated_at_set_on_download_completion` | FR-007 | `updatedAt` set after download |
| `cache_entry_has_all_required_fields` | FR-008 | All mandatory fields present in persisted entry |
| `delete_single_cache_entry` | FR-009 | File deleted and index entry removed |
| `delete_set_of_cache_entries` | FR-010 | Multiple files and entries removed |
| `clear_expired_entries` | FR-011 | Only entries with past `expiresAt` removed |
| `non_expired_entries_untouched` | FR-011 | Entries with future or null `expiresAt` preserved |
| `repair_stale_entries` | FR-012 | Missing-file entries removed from index |
| `cleanup_no_remote_operations` | FR-013 | Transport mock asserts zero remote calls during cleanup |
| `cached_task_emits_cached_state` | FR-014 | Stream emits `FileTaskState.cached` for cached file |
| `sha256_mismatch_triggers_redownload` | FR-017 | Hash mismatch → cache miss → re-download |
| `concurrent_requests_deduplicated` | FR-018 | Two simultaneous first-time requests → one download task |
| `cached_metadata_returned_on_cache_hit` | FR-019 | `task.cachedMetadata` non-null with correct fields |

---

## Migration Notes (for CHANGELOG.md)

### `fix: clearCache() and clearCacheForUrls() now also remove index entries`

Previously, these methods only deleted the local file; the `FilePathAndURLRepository` index entry remained, causing the next request to attempt to verify a file that no longer existed (stale entry). Now both the file and index entry are removed atomically.

### `fix: default cache directory changed to applicationSupportDirectory/cached`

The previous default (`applicationDocumentsDirectory/cached`) is visible in iOS Files app and survives iCloud backups. The correct location for a package-managed cache is `applicationSupportDirectory`, which is hidden from users and backed up more selectively. Existing cached files in the old directory will appear as cache misses. To preserve the old behavior, pass `cacheDirectory: (await getApplicationDocumentsDirectory()).path + '/cached'` to `TransferKitConfig.init()`.

---

## Phase 0 Output

See [research.md](research.md) — all decisions finalized, no NEEDS CLARIFICATION items remain.

## Phase 1 Output

- [data-model.md](data-model.md) — entity field additions, state transitions, affected files
- [contracts/public-api.md](contracts/public-api.md) — full API contracts with backward-compat matrix
- [quickstart.md](quickstart.md) — usage guide for all new features

## Next Step

Run `/speckit-tasks` to generate the task breakdown from this plan.
