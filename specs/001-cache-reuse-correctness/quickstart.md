# Quickstart: Cache Reuse and Local Cache Correctness

This guide shows how to use the new cache features introduced in this feature branch.

---

## 1. Basic Cache Hit (no changes needed)

Existing code already gets cache hit behavior after this fix. A file downloaded once will be returned from cache on subsequent requests:

```dart
// First download — network request made
final task = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(url: fileUrl),
  taskId: 'my-file-001',
);
// task.state == FileTaskState.completed

// Second request — served from cache, zero network calls
final cachedTask = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(url: fileUrl),
  taskId: 'my-file-001-v2',
);
// cachedTask.state == FileTaskState.cached
// cachedTask.filePath   → local file path
// cachedTask.cachedMetadata → MediaMetadata (image dimensions, duration, etc.)
```

---

## 2. Stable Cache Key for Signed / Rotating URLs

Firebase signed URLs change on every generation. Without an explicit cache key, each new URL = a cache miss. Pass a stable `cacheKey` to get reliable reuse:

```dart
// Both calls use the same cache key → same local file → single download
final task1 = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(
    url: 'https://storage.googleapis.com/...?token=abc123',
    cacheKey: 'club/media/photo_001.jpg', // stable key
  ),
  taskId: 'photo-001-a',
);

final task2 = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(
    url: 'https://storage.googleapis.com/...?token=xyz789', // different token
    cacheKey: 'club/media/photo_001.jpg', // same stable key → cache hit
  ),
  taskId: 'photo-001-b',
);
// task2.state == FileTaskState.cached
```

---

## 3. Forced Refresh

Download the latest version even when a valid cached copy exists:

```dart
final task = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(
    url: fileUrl,
    cacheKey: 'my-document.pdf',
  ),
  taskId: 'doc-refresh-${DateTime.now().millisecondsSinceEpoch}',
  forceRefresh: true,  // bypasses cache, downloads fresh
);
// task.state == FileTaskState.completed (never cached)
```

---

## 4. Accessing Cached File Metadata

When a cache hit occurs, file metadata (image dimensions, video duration, audio waveform, document page count) is returned alongside the file path:

```dart
final task = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(url: imageUrl),
  taskId: 'image-001',
);

if (task.isCached) {
  final meta = task.cachedMetadata;
  print('Width: ${meta?.width}');
  print('Height: ${meta?.height}');
  print('MIME: ${meta?.mimeType}');
  // For audio files (when autoExtractWaveform: true):
  print('Waveform samples: ${meta?.waveform?.samples.length}');
}
```

---

## 5. Cache Expiration

Set an expiry when creating the download request. Expired entries are treated as cache misses:

```dart
// This file expires in 24 hours
final task = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(
    url: fileUrl,
    expiresAt: DateTime.now().add(const Duration(hours: 24)),
  ),
  taskId: 'expiring-file-001',
);
```

---

## 6. Cache Cleanup Operations

```dart
final kit = TransferKit();

// Remove a single file from cache (file + index entry)
await kit.clearCache(fileUrl);

// Remove multiple files
await kit.clearCacheForUrls({'url1', 'url2', 'url3'});

// Remove all entries whose expiresAt has passed
final removedCount = await kit.clearExpiredCacheEntries();
print('Cleaned $removedCount expired entries');

// Repair stale entries (index records pointing to missing files)
final repairedCount = await kit.repairStaleCacheEntries();
print('Repaired $repairedCount stale entries');
```

---

## 7. SHA-256 Verification (opt-in)

Enable content-hash verification in the config. TransferKit will compute the SHA-256 of the downloaded file and re-verify it on every cache hit:

```dart
await TransferKitConfig.init(
  autoExtractSha256: true, // compute & store hash at download time
  // ... other config ...
);

// On next cache lookup, if the file's hash doesn't match the stored hash,
// it's treated as a cache miss and re-downloaded automatically.
```

---

## 8. Configurable Cache Directory

```dart
// Use the default (applicationSupportDirectory/cached)
await TransferKitConfig.init();

// Override to a custom directory
final customPath = '/path/to/custom/cache';
await TransferKitConfig.init(
  cacheDirectory: customPath,
);

// Preserve the old behavior (applicationDocumentsDirectory/cached)
final docsDir = await getApplicationDocumentsDirectory();
await TransferKitConfig.init(
  cacheDirectory: '${docsDir.path}/cached',
);
```

**Note**: The default cache directory changed from `applicationDocumentsDirectory/cached` to `applicationSupportDirectory/cached`. Existing cached files in the old location will appear as cache misses unless you pass the old path explicitly.

---

## 9. Waveform Data for Audio Files

Enable waveform extraction in the config. Waveform data is extracted after download and returned on cache hit:

```dart
await TransferKitConfig.init(
  autoExtractWaveform: true,
);

final task = await TransferKit().downloadTask(
  filePathAndUrl: FilePathAndURL.url(url: audioUrl),
  taskId: 'audio-001',
);

if (task.isCached && task.cachedMetadata?.waveform != null) {
  final waveform = task.cachedMetadata!.waveform!;
  renderWaveform(waveform.samples);
}
```
