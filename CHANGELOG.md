# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- **Metadata Configuration Options** - New settings in `FileManagementConfig`:
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

- `FileManagementConfig` - New singleton class for library-wide configuration
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
FileManagementConfig.init(
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
- `FileManagementSystem` - Main controller for file operations
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
