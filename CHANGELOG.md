# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking Changes

- **Notifications are now opt-in**: TransferKit no longer renders notifications
  automatically. The previous always-on `BackgroundTransferService`-driven
  notifications have been removed. To restore notifications, pass a
  `TransferNotificationConfig(enabled: true)` to `TransferKitConfig.init()`.
- **`BackgroundTransferService`**: removed direct `awesome_notifications`
  coupling, channel constants (`notificationChannelKey`,
  `notificationChannelName`, `notificationChannelDescription`,
  `channel()`), notification ID range constants, and the private rendering
  helpers (`_createOrUpdateNotification`, `_createOrUpdateBatchNotification`,
  `_getProgressNotificationId`, `_getSuccessNotificationId`,
  `_getFailureNotificationId`). The service now only manages background
  scheduling; rendering is delegated to the new notification surface.

### Added — Notification Control & UI

- `TransferNotificationConfig` — central, immutable notification configuration.
  Master `enabled` switch, per-direction (`uploadEnabled`, `downloadEnabled`),
  per-state (`showProgress`, `showCompletion`, `showErrors`, `showCancelled`,
  `showPaused`, `showRetry`), `throttleDuration` (default 1 s),
  `grouping` (`perFile` / `batch` / `none`), `requestPermissionOnInit`, and
  optional custom `adapter`.
- `TransferNotificationTemplate` — customizable text, icons, and channel for
  each direction. Supports a `localization` map and a `resolveText(key,
  payload)` callback for full developer control.
- `TransferNotificationAdapter` — public abstraction interface so any
  notification SDK (or none) can be wired in. Mirrors the `TransferDriver`
  pattern (Principle VI).
- `AwesomeNotificationAdapter` — built-in default adapter. Lazy channel
  registration; silent no-op on macOS / Windows / Linux / Web.
- `TransferNotificationPayload`, `NotificationGroupingMode`,
  `NotificationPermissionStatus`, `NotificationEventKind`, `TransferType`,
  `TransferNotificationAction` — supporting public types.
- `TransferKit.instance.checkNotificationPermission()` and
  `requestNotificationPermission()` — opt-in permission helpers (FR-013).
- `FakeNotificationAdapter` (in `test/src/notification/fake/`) — canonical
  test double recording every adapter call for assertions.
- `TransferKitConfig.notificationConfig` getter and
  `setNotificationConfig(...)` runtime mutator.
- New tests under `test/src/notification/` covering policy, coordinator,
  throttle, batch grouping, fake adapter, resilience (FR-014), and
  permission semantics (SC-007).

### Migration

If your app relied on the old implicit notifications, add to
`TransferKitConfig.init`:

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
  ),
);
```

To stay silent (the new default), omit `notificationConfig` entirely.

## [3.0.0] - 2026-05-07

### Breaking Changes

- **Firebase removed**: `transfer_kit` no longer depends on `firebase_storage` or
  `cloud_firestore`. Remove these from your `pubspec.yaml` if added solely for TransferKit.
- **Driver injection required**: `TransferKitConfig.init()` now requires a `driver`
  parameter. There is no default Firebase driver. See [MIGRATION.md](MIGRATION.md).
- **FileTask**: Removed `task`, `firebaseTask()`, `reference`, and the
  `.upload(UploadTask?)` constructor.
- **Extensions**: Removed `toTimestamp()`, `objectToTimestamp()`,
  `getDocumentReference()`, `getTimestamp()`, `mapCanConvertToFirebase()`,
  and `GeoPointExtension`.

### Added

- `TransferDriver` abstract interface — implement to use any storage backend.
- `TransferCapabilities` — immutable capability declaration for drivers.
- `DownloadRequest` / `UploadRequest` — generic, credential-free transfer request types.
- `TransferProgressEvent` sealed class hierarchy (`TransferProgressUpdate`,
  `TransferCompleted`, `TransferFailed`).
- `UnsupportedCapabilityException` — thrown synchronously when a driver capability
  is not supported.
- `HttpDownloadDriver` — built-in HTTP/HTTPS download driver with cancellation support.
- `LocalFileCopyDriver` — built-in on-device file copy driver; also serves as
  the canonical reference implementation for custom driver authors.

### Migration

See [MIGRATION.md](MIGRATION.md) for the complete guide, including a drop-in
`FirebaseStorageDriver` adapter example for existing Firebase users.

---

## [2.2.0] - 2026-05-07

### Added

#### Cache Reuse and Local Cache Correctness

- **`cacheKey` support** on `FilePathAndURL` and download APIs — callers can supply a stable key (e.g. storage path) so that signed URLs with rotating query strings still hit the same cache entry
- **`expiresAt` TTL** on `FilePathAndURL` — cache entries are treated as misses and removed when `expiresAt` is in the past; `clearExpiredCacheEntries()` bulk-purges all expired entries
- **`lastAccessedAt` timestamp** updated automatically on every cache hit
- **`createdAt` / `updatedAt` timestamps** stamped on `FilePathAndURL` at creation and on each download completion
- **`cachedMetadata`** field on `FileTask` — populated from the cache entry on a cache hit so callers receive media metadata without a redundant download
- **`forceRefresh`** parameter on `downloadTask` / `downloadTaskStream` — bypasses the cache, deletes the existing local file and index entry, and triggers a fresh download; the resulting task state is never `.cached`
- **`repairStaleCacheEntries()`** on `TransferKit` — scans the index and removes entries whose local file no longer exists; returns the count of entries removed
- **`clearExpiredCacheEntries()`** on `TransferKit` — deletes local files and removes index entries where `expiresAt` has passed; returns the count of entries removed
- **`repairStaleEntries()`** / **`clearExpiredEntries()`** on `FilePathAndURLRepository` — lower-level counterparts used internally
- **`cacheDirectory`** option in `TransferKitConfig.init()` — overrides the local path used for cached files

### Changed

- **Default cache directory** changed from `applicationDocumentsDirectory/cached` to `applicationSupportDirectory/cached` to align with platform conventions for application-managed data
- **`clearCache(url)`** now removes the index entry from `FilePathAndURLRepository` in addition to deleting the local file, keeping the cache index consistent

### Fixed

- Stale cache entries (local file deleted externally) are now detected on lookup and removed from the index rather than returning a broken path

---

## [2.1.0] - 2026-01-08

### Added

#### Enhanced Metadata Extraction

- **PDF Thumbnail Extraction** - Renders first page of PDF as thumbnail image
  - Uses `pdfx` package for native PDF rendering
  - Respects `autoExtractThumbnail` configuration
  - Maintains aspect ratio with configurable max dimensions
- **Audio Waveform Extraction** - Full waveform visualization support
  - Uses `just_waveform` package for waveform generation
  - Normalized amplitude samples (0.0 to 1.0)
  - Configurable samples per second via `waveformSamplesPerSecond`
  - New `autoExtractWaveform` configuration option
- **Metadata Configuration Options** - New settings in `TransferKitConfig`:
  - `autoExtractMetadata` - Enable/disable automatic metadata extraction
  - `autoExtractSha256` - Enable/disable SHA-256 hash computation
  - `autoExtractThumbnail` - Enable/disable thumbnail generation
  - `autoExtractWaveform` - Enable/disable audio waveform extraction
  - `thumbnailMaxWidth` / `thumbnailMaxHeight` - Thumbnail dimensions
  - `waveformSamplesPerSecond` - Waveform resolution

### Changed

#### Dependencies

- **Replaced** `lecle_flutter_carousel_pro` with `carousel_slider` (^5.0.0)
  - More popular and actively maintained
  - Better API and customization options
  - Added `autoPlay` and `autoPlayInterval` parameters to `DownloadImageSliderWidget`
- **Updated** `just_waveform` to correct version ^0.0.7

#### Improvements

- `DownloadImageSliderWidget` converted to `StatefulWidget` for proper indicator state
- Custom dot indicators with active state tracking
- PDF metadata now includes thumbnail when enabled

---

## [2.0.0] - 2026-01-07

### Added

#### Centralized Configuration System

- `TransferKitConfig` - New singleton class for library-wide configuration
  - `maxConcurrentDownloads` - Limit simultaneous downloads (default: 5)
  - `maxConcurrentUploads` - Limit simultaneous uploads (default: 3)
  - `streamCleanupDelay` - Delay before cleaning unused streams (default: 3s)
  - `enableLogging` - Toggle debug logging
  - `retryAttempts` - Configure retry behavior
  - `cacheEnabled` / `maxCacheSize` / `cacheExpiration` - Cache settings
- Runtime configuration updates via setter methods
- `toMap()` method for debugging configuration state

#### Stream Sharing Pattern

- Shared broadcast streams for download/upload operations
- Reference counting for automatic resource cleanup
- Delayed cleanup to prevent rapid stream re-creation during widget rebuilds
- `FirebaseStorageFactory.getDownloadStream()` - Get or create shared download stream
- `FirebaseStorageFactory.getUploadStream()` - Get or create shared upload stream
- `FirebaseStorageFactory.getActiveStreamStats()` - Monitor stream sharing efficiency

#### Enhanced Exception System

- `FileException` - New abstract base class with error chaining support
- `cause` property - Store original exception for debugging
- `stackTrace` property - Preserve original stack trace
- `FileCacheException` - New exception for cache operations
- `FileTaskException` - New exception for task operations

#### Media Metadata System

- `MediaMetadata` - Comprehensive metadata class for all file types
  - Common: mimeType, fileSize, sha256, fileName, fileExtension, timestamps
  - Images: width, height, aspectRatio, orientation, colorSpace, bitDepth
  - Video/Audio: duration, frameRate, codecs, bitrate, sample rate
  - Documents: pageCount, title, author, subject, keywords
  - Custom: extensible customData map
- `WaveformData` - Audio waveform visualization data
- `ThumbnailData` - Thumbnail storage for images/videos/documents
- `MetadataExtractionService` - Automatic metadata extraction from local files
- `MetadataSource` enum - Track metadata origin (api, firebase, cache, local)
- Metadata integrated into `FilePathAndURL` for seamless caching
- Automatic metadata extraction on download/upload completion
- Metadata merging from multiple sources (API + local extraction)

### Changed

#### Performance Improvements

- **O(n²) to O(n) optimization**: Convert `Set.elementAt()` loops to `List` indexing
- **Pre-computed filter conditions**: Optimize `streamTasksBy()` and `getTasksBy()` methods
- **Immediate completion tracking**: Replace `Future.delayed` with direct tracking
- **Stream sharing**: Multiple subscribers share single Firebase listener

#### Code Quality

- Fixed typo: `Repositry` → `Repository` across all files (4 files renamed)
- Unified comment language: All Arabic comments converted to English
- Unified UI text: All Arabic strings converted to English
- Enhanced documentation with comprehensive English comments

#### Security

- Added path traversal protection in `file_path_extension.dart`
- Validate file paths stay within app directory bounds

#### Bug Fixes

- Fixed `_filePathAndURL` cache invalidation in `FileTask`
- Improved `StreamController` lifecycle management with `onCancel` callbacks
- Added `isClosed` checks before stream operations
- Replaced custom `math.dart` with standard `dart:math`

### Removed

- `lib/src/core/extension/math.dart` - Replaced with `dart:math`

### Migration Notes

Existing code continues to work without changes. New features are opt-in:

```dart
// Optional: Configure the library
TransferKitConfig.init(
  maxConcurrentDownloads: 3,
  enableLogging: true,
);

// New: Exception chaining
try {
  await download();
} on FileDownloadException catch (e) {
  print('Cause: ${e.cause}');
}

// New: Monitor stream efficiency
final stats = FirebaseStorageFactory.getActiveStreamStats();

// New: Pass metadata from API with download request
final task = await fileManager.downloadTask(
  filePathAndUrl: FilePathAndURL.url(
    url: imageUrl,
    metadata: MediaMetadata(
      mimeType: 'image/jpeg',
      width: 1920,
      height: 1080,
      fileSize: 1024000,
    ),
  ),
  taskId: 'download_001',
);

// After download, metadata is available and cached
final cachedFile = await fileManager.getCachedFile(imageUrl);
print('Dimensions: ${cachedFile?.metadata?.width}x${cachedFile?.metadata?.height}');
```

---

## [1.0.0] - 2024-01-07

### Added

- Initial release
- `TransferKit` - Main controller for file operations
- `FileTask` - Task model with state management
- `FilePathAndURL` - Path/URL handling model
- File upload with progress tracking
- File download with progress tracking
- Batch operations (parallel/sequential)
- Task control (pause, resume, cancel, retry)
- Intelligent file caching
- Background transfer support
- UI Widgets:
  - `FileLoadingCard` - Download progress card
  - `FileUploadCard` - Upload progress card
  - `FileTaskItem` - Detailed task item
  - `FileTaskCard` - Compact task card
  - `FileTaskTile` - Task tile widget
  - `MultiUploadProgressListView` - Batch upload progress
  - `FileDownloadProgressListView` - Batch download progress
- Media Widgets:
  - `DownloadImageWidget` - Image with automatic caching
  - `DownloadVideoWidget` - Video with thumbnail preview
  - `DownloadImageSliderWidget` - Image carousel
  - `MediaDownloadCard` - Generic media download card
  - `DocumentDownloadCard` - Document download card
