# Public API Contracts: Cache Reuse and Local Cache Correctness

**Feature**: 001-cache-reuse-correctness  
**Date**: 2026-05-07  
**Stability**: All changes are additive. Existing method signatures are unchanged.

---

## 1. TransferKitConfig.init() — new `cacheDirectory` parameter

```dart
static Future<void> init({
  // ... all existing parameters unchanged ...
  int? maxConcurrentDownloads,
  int? maxConcurrentUploads,
  Duration? streamCleanupDelay,
  bool? defaultAutoStart,
  bool? enableLogging,
  int? retryAttempts,
  Duration? retryDelay,
  bool? cacheEnabled,
  int? maxCacheSize,
  Duration? cacheExpiration,
  bool? autoExtractMetadata,
  bool? autoExtractSha256,
  bool? autoExtractThumbnail,
  bool? autoExtractWaveform,
  int? thumbnailMaxWidth,
  int? thumbnailMaxHeight,
  int? waveformSamplesPerSecond,
  // NEW:
  String? cacheDirectory,  // Absolute path; null = applicationSupportDirectory/cached
}) async
```

**New getter added to TransferKitConfig**:
```dart
String? get cacheDirectory;  // null means "use default"
```

**Breaking behavior change**: When `cacheDirectory` is null (the default), the cache now defaults to `applicationSupportDirectory/cached` instead of the previous `applicationDocumentsDirectory/cached`. Callers who relied on the old path must pass the old path explicitly.

---

## 2. FilePathAndURL.url() — new `cacheKey` parameter

```dart
// BEFORE
FilePathAndURL.url({required String url, MediaMetadata? metadata});

// AFTER (additive — cacheKey is optional)
FilePathAndURL.url({
  required String url,
  MediaMetadata? metadata,
  String? cacheKey,    // NEW: explicit stable key; null = use full URL
  DateTime? expiresAt, // NEW: optional expiry for this entry
});
```

When `cacheKey` is provided:
- Local path = `cacheKey.toHashName().toCachedPath()`
- Stored in `data['cacheKey']`

When `cacheKey` is null:
- Local path = `url.toHashName().toCachedPath()` (existing behavior)

---

## 3. FileTask — new `cachedMetadata` getter

```dart
/// Metadata extracted from the cached file at the time of cache hit.
/// Non-null only when [state] == [FileTaskState.cached].
MediaMetadata? get cachedMetadata;
```

Accessible on any `FileTask` returned from a download operation. Callers that previously needed to query `FilePathAndURLRepository.instance.getByUrl(url)?.metadata` can now use `task.cachedMetadata` directly.

---

## 4. FirebaseFileRepository.createDownloadTask() — new parameters

```dart
// BEFORE
Future<FileTask> createDownloadTask({
  required FilePathAndURL filePathAndUrl,
  required String taskId,
  required FileGroupInfo group,
  bool autoStart = true,
});

// AFTER (additive)
Future<FileTask> createDownloadTask({
  required FilePathAndURL filePathAndUrl,
  required String taskId,
  required FileGroupInfo group,
  bool autoStart = true,
  bool forceRefresh = false, // NEW: bypass cache and replace entry on completion
});
```

When `forceRefresh = true`:
- Cache lookup is skipped entirely.
- If an existing local file and index entry exist for the cache key, the file is deleted and the entry is removed.
- A new download is initiated; on completion the cache entry is created fresh.
- The task emits `FileTaskState.running` → `FileTaskState.completed` (never `cached`).

---

## 5. TransferKit.downloadTaskStream() / downloadTask() — new parameter

```dart
// Both methods gain the same new optional parameter:
Stream<FileTask> downloadTaskStream({
  required FilePathAndURL filePathAndUrl,
  bool autoStart = true,
  required String taskId,
  FileGroupInfo? group,
  bool forceRefresh = false, // NEW
});

Future<FileTask> downloadTask({
  required FilePathAndURL filePathAndUrl,
  required String taskId,
  bool autoStart = true,
  FileGroupInfo? group,
  bool forceRefresh = false, // NEW
});
```

---

## 6. TransferKit — new cache management methods

```dart
/// Deletes local files and removes index entries where expiresAt has passed.
/// Returns the number of entries removed.
/// Does NOT perform any remote file operations.
Future<int> clearExpiredCacheEntries();

/// Removes index entries where the local file no longer exists on disk.
/// Returns the number of stale entries repaired.
/// Does NOT perform any remote file operations.
Future<int> repairStaleCacheEntries();
```

**Updated existing methods** (behavior change — now also removes the index entry):

```dart
/// Clears the cached file for the given URL.
/// Deletes the local file AND removes the entry from FilePathAndURLRepository.
Future<void> clearCache(String url);

/// Clears cached files for the given URLs.
/// Deletes local files AND removes entries from FilePathAndURLRepository.
Future<void> clearCacheForUrls(Set<String> urls);
```

---

## 7. FilePathAndURL.copyWith() — extended

```dart
FilePathAndURL copyWith({
  String? url,
  String? destinationPath,
  MediaMetadata? metadata,
  String? cacheKey,          // NEW
  DateTime? createdAt,       // NEW
  DateTime? updatedAt,       // NEW
  DateTime? lastAccessedAt,  // NEW
  DateTime? expiresAt,       // NEW
});
```

---

## 8. FilePathAndURLRepository — new methods

```dart
/// Lookup by explicit cache key (for callers who provided a cacheKey).
FilePathAndURL? getByKey(String cacheKey);

/// Updated signature: accepts optional cacheKey for stable lookup.
/// Also performs: stale removal, expiry check, SHA-256 verification,
/// lastAccessedAt update.
Future<FilePathAndURL?> getCachedDownloadFilePathAndURL({
  required String url,
  String? cacheKey,          // NEW
});

/// Removes entries where expiresAt is in the past;
/// deletes associated local files.
/// Returns count of removed entries.
Future<int> clearExpiredEntries();

/// Removes entries where the local file no longer exists.
/// Returns count of repaired entries.
Future<int> repairStaleEntries();
```

---

## Backward Compatibility Matrix

| API Surface | Status | Notes |
|-------------|--------|-------|
| `TransferKitConfig.init()` | ✅ Compatible | New optional `cacheDirectory` param; defaults to new directory |
| `FilePathAndURL.url()` | ✅ Compatible | New optional `cacheKey`, `expiresAt` params |
| `FilePathAndURL.copyWith()` | ✅ Compatible | New optional params |
| `FileTask.cachedMetadata` | ✅ Compatible | New getter; null for existing tasks |
| `FirebaseFileRepository.createDownloadTask()` | ✅ Compatible | New optional `forceRefresh` param |
| `TransferKit.downloadTaskStream()` | ✅ Compatible | New optional `forceRefresh` param |
| `TransferKit.downloadTask()` | ✅ Compatible | New optional `forceRefresh` param |
| `TransferKit.clearCache()` | ⚠️ Behavior change | Now also removes index entry (was: file only) |
| `TransferKit.clearCacheForUrls()` | ⚠️ Behavior change | Now also removes index entries (was: files only) |
| `FilePathAndURLRepository.getCachedDownloadFilePathAndURL()` | ⚠️ Behavior change | Adds stale removal, expiry check, lastAccessedAt update; new optional `cacheKey` param |
| Default cache directory | ⚠️ Breaking behavior | Changed from `applicationDocumentsDirectory/cached` to `applicationSupportDirectory/cached` |

**Note on behavior changes**: These are corrections to incorrect or incomplete prior behavior. They are documented in CHANGELOG.md as `fix:` entries per the constitution's Principle XII.
