# TransferKit

[![pub package](https://img.shields.io/pub/v/transfer_kit.svg)](https://pub.dev/packages/transfer_kit)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-All-blueviolet)](https://flutter.dev)

**Provider-agnostic file transfer solution for Flutter — smart caching, stream sharing, and pluggable backends.**

> **Upgrading from 2.x?** See [MIGRATION.md](MIGRATION.md).

```dart
FileLoadingCard(
  url: 'https://cdn.example.com/image.jpg',
  onLoaded: (file) => Image.file(file),
)
```

## Overview

**TransferKit** provides a complete solution for handling file uploads and downloads in Flutter applications. Built with performance and developer experience in mind, it offers intelligent caching, progress tracking, task management, and beautiful pre-built UI components.

### Why TransferKit?

| Feature | Benefit |
|---------|---------|
| **Stream Sharing** | Multiple widgets requesting the same file share a single stream, reducing memory and network overhead |
| **Smart Caching** | Automatic file caching prevents redundant downloads |
| **Task Persistence** | Transfer state survives app restarts |
| **Pre-built Widgets** | Production-ready UI components for common use cases |
| **Type Safety** | Full Dart null-safety support with comprehensive type definitions |

---

## Features

- **File Upload & Download** — Provider-agnostic with real-time progress tracking via any `TransferDriver`
- **Stream Sharing** — Optimized resource usage when multiple widgets request the same file
- **Smart Caching** — Automatic file caching to avoid redundant downloads
- **Task Management** — Pause, resume, cancel, and retry file operations
- **Batch Operations** — Upload/download multiple files in parallel or sequentially
- **Persistent State** — Task state persists across app restarts
- **Background Transfers** — Continue transfers when app is in background
- **Rich UI Components** — Beautiful, customizable widgets for file operations
- **Progress Tracking** — Real-time progress updates with transfer speed and ETA
- **Error Handling** — Comprehensive exception handling with error chaining

---

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  transfer_kit: ^3.0.0
```

No Firebase packages required.

### Basic Setup

Initialize with a driver and optional configuration:

```dart
import 'package:transfer_kit/transfer_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await TransferKitConfig.init(
    // Required: choose a driver (or implement your own)
    driver: HttpDownloadDriver(
      headers: {'Authorization': 'Bearer $myToken'},
    ),
    maxConcurrentDownloads: 3,
    maxConcurrentUploads: 2,
    streamCleanupDelay: Duration(seconds: 5),
    enableLogging: kDebugMode,
    cacheEnabled: true,
    maxCacheSize: 1024 * 1024 * 1024, // 1 GB
  );

  runApp(MyApp());
}
```

### Download a File

```dart
// Using the widget (recommended)
FileLoadingCard(
  url: 'https://firebasestorage.googleapis.com/.../image.jpg',
  onLoaded: (file) => Image.file(file),
)

// Using the API directly
final fileManager = TransferKit();
final task = await fileManager.downloadTask(
  filePathAndUrl: FilePathAndURL.url(url: imageUrl),
  taskId: 'download_001',
);
```

### Upload a File

```dart
// Using the widget
FileUploadCard(
  filePath: '/path/to/file.jpg',
  destinationPath: 'uploads/file.jpg',
  onUploaded: (task) => Text('Uploaded: ${task.downloadUrl}'),
)

// Using the API directly
final task = await fileManager.uploadTask(
  filePathAndUrl: FilePathAndURL.local(
    path: '/path/to/file.jpg',
    destinationPath: 'uploads/file.jpg',
  ),
  taskId: 'upload_001',
  group: FileGroupInfo(id: 'my_uploads'),
);
```

---

## Architecture

### Stream Sharing Pattern

When multiple widgets request the same file, the library automatically shares a single stream:

```
Widget A ─┐
Widget B ─┼──► Single Firebase Task ──► Shared Broadcast Stream
Widget C ─┘         │                          │
                    ▼                          ▼
             One snapshotEvents          All widgets receive
                 listener                  same updates
```

This architecture provides:

- **Reduced Memory Usage** — One listener per unique transfer
- **Consistent State** — All widgets see the same progress
- **Automatic Cleanup** — Resources freed when all subscribers disconnect

---

## Core API

### TransferKit

The main controller for all file operations.

```dart
final fileManager = TransferKit();

// Download operations
Future<FileTask> downloadTask({...});
Stream<FileTask> downloadTaskStream({...});
Stream<MultiDownloadFileTask> downloadTasksParallelStream({...});

// Upload operations
Future<FileTask> uploadTask({...});
Stream<FileTask> uploadTaskStream({...});
Stream<MultiUploadFileTask> uploadTasksParallelStream({...});

// Task control
Future<bool> startTask(String taskId);
Future<bool> pauseTask(String taskId);
Future<bool> resumeTask(String taskId);
Future<bool> cancelTask(String taskId);
Future<bool> retryTask(String taskId);

// Queries
FileTask? getTaskById(String taskId);
Set<FileTask> getTasksByGroupId(String groupId);
Stream<FileTask?> getTaskStreamById(String taskId);
```

### FileTask

Represents a file transfer operation.

```dart
class FileTask {
  final String id;
  final String? filePath;
  final String? downloadUrl;
  final FileTaskState state;
  final FileTaskType type;
  final FileProgress progress;

  // Computed properties
  bool get isComplete;
  bool get isRunning;
  bool get isPaused;
  double get progressPercentage;
  int get bytesTransferred;
  int get totalBytes;
}
```

### Task States

```dart
enum FileTaskState {
  waiting,    // Queued but not started
  running,    // Actively transferring
  paused,     // Paused by user
  completed,  // Successfully completed
  error,      // Encountered an error
  cancelled,  // Cancelled by user
  cached,     // Served from cache
}
```

---

## Widgets

### FileLoadingCard

Downloads and displays a file with progress indication.

```dart
FileLoadingCard(
  url: 'https://example.com/image.jpg',
  onLoaded: (file) => Image.file(file, fit: BoxFit.cover),
  downloadingWidget: (context, task) => CircularProgressIndicator(
    value: task?.progressPercentage ?? 0 / 100,
  ),
  onError: (error) => Icon(Icons.error),
  checkCacheFirst: true,
)
```

### FileUploadCard

Uploads a file with progress indication.

```dart
FileUploadCard(
  filePath: '/path/to/file.pdf',
  destinationPath: 'documents/report.pdf',
  onUploaded: (task) => Column(
    children: [
      Icon(Icons.check_circle, color: Colors.green),
      Text('Upload complete!'),
      SelectableText(task.downloadUrl!),
    ],
  ),
  uploadingWidget: (context, task) => LinearProgressIndicator(
    value: task?.progressPercentage ?? 0 / 100,
  ),
)
```

### MultiFileLoadingCard

Downloads multiple files with combined progress.

```dart
MultiFileLoadingCard(
  urls: {'url1', 'url2', 'url3'},
  isSequential: false, // Download in parallel
  onLoaded: (files) => GridView.builder(
    itemCount: files.length,
    itemBuilder: (_, i) => Image.file(files[i]),
  ),
  onFileLoaded: (file, index) => print('File $index downloaded'),
  onAllFilesLoaded: (files) => print('All ${files.length} files ready'),
)
```

### MultiFileUploadCard

Uploads multiple files with combined progress.

```dart
MultiFileUploadCard(
  filePathsAndUrls: {
    FilePathAndURL(path: '/file1.jpg', destinationPath: 'uploads/1.jpg'),
    FilePathAndURL(path: '/file2.jpg', destinationPath: 'uploads/2.jpg'),
  },
  onUploaded: (downloadUrls) => Text('Uploaded ${downloadUrls.length} files'),
  onFileUploaded: (url, index) => print('File $index: $url'),
)
```

### Media Widgets

Pre-built widgets for common media types:

```dart
// Image with automatic caching
DownloadImageWidget(
  file: FileModel(url: 'https://example.com/photo.jpg'),
  fit: BoxFit.cover,
  onTap: (context, filePath) => openImageViewer(filePath),
)

// Video with thumbnail preview
DownloadVideoWidget(
  file: FileModel(
    url: 'https://example.com/video.mp4',
    thumbnail: thumbnailBytes,
    durationInSeconds: 120,
  ),
  onTap: (context, filePath) => playVideo(filePath),
)

// Image carousel
DownloadImageSliderWidget(
  imageFiles: [file1, file2, file3],
  height: 300,
  autoStart: true,
)
```

---

## Advanced Usage

### Batch Operations with Progress

```dart
final groupId = 'batch_${DateTime.now().millisecondsSinceEpoch}';

// Monitor batch progress
fileManager.streamTasksBy(groupId: groupId).listen((tasks) {
  final completed = tasks.where((t) => t.isComplete).length;
  final total = tasks.length;
  final totalBytes = tasks.fold<int>(0, (sum, t) => sum + t.totalBytes);
  final transferred = tasks.fold<int>(0, (sum, t) => sum + t.bytesTransferred);

  print('Progress: $completed/$total files');
  print('Transferred: ${transferred.formatBytes} / ${totalBytes.formatBytes}');
});
```

### Custom Error Handling

```dart
try {
  await fileManager.downloadTask(...);
} on FileDownloadException catch (e) {
  print('Download failed: ${e.message}');
  print('Cause: ${e.cause}');
  print('Stack trace: ${e.stackTrace}');
} on FileCacheException catch (e) {
  print('Cache error: ${e.message}');
}
```

### Stream Statistics

Monitor the efficiency of stream sharing:

```dart
final stats = FirebaseStorageFactory.getActiveStreamStats();
print('Active download streams: ${stats['downloadStreams']}');
print('Active upload streams: ${stats['uploadStreams']}');
print('Total download subscribers: ${stats['downloadSubscribers']}');
print('Total upload subscribers: ${stats['uploadSubscribers']}');
```

### Cache Management

```dart
// Check if file is cached
final isCached = await fileManager.isFileCached(url);

// Get cached file path
final cachedPath = await fileManager.getCachedFilePath(url);

// Clear a specific URL from cache (removes index entry + local file)
await fileManager.clearCache(url: url);

// Clear all cache
await fileManager.clearCache();

// Force a fresh download, ignoring any cached version
final stream = fileManager.downloadTaskStream(
  url: url,
  taskId: 'task-1',
  group: FileGroupInfo(id: 'grp'),
  forceRefresh: true,
);

// Use a stable cache key for signed URLs (rotating query strings)
final stream2 = fileManager.downloadTaskStream(
  url: 'https://storage.example.com/file.jpg?token=abc123',
  taskId: 'task-2',
  group: FileGroupInfo(id: 'grp'),
  cacheKey: 'media/file.jpg', // stable identifier
);

// Access cached media metadata on a cache-hit task
final task = await fileManager.downloadTask(url: url, taskId: 'task-3', group: FileGroupInfo(id: 'grp'));
if (task.isCached) {
  final meta = task.cachedMetadata; // MediaMetadata? — populated without downloading
  print('MIME: ${meta?.mimeType}, size: ${meta?.fileSize}');
}

// Remove stale index entries (local file was deleted externally)
final repairedCount = await fileManager.repairStaleCacheEntries();

// Remove entries whose TTL has expired and delete their local files
final clearedCount = await fileManager.clearExpiredCacheEntries();
```

---

## Configuration

### TransferKitConfig

The library provides a centralized configuration system for customizing behavior.

#### Available Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `maxConcurrentDownloads` | `int` | 5 | Maximum simultaneous downloads |
| `maxConcurrentUploads` | `int` | 3 | Maximum simultaneous uploads |
| `streamCleanupDelay` | `Duration` | 3 seconds | Delay before cleaning unused streams |
| `defaultAutoStart` | `bool` | true | Auto-start transfers by default |
| `enableLogging` | `bool` | false | Enable debug logging |
| `retryAttempts` | `int` | 3 | Number of retry attempts on failure |
| `retryDelay` | `Duration` | 2 seconds | Delay between retry attempts |
| `cacheEnabled` | `bool` | true | Enable file caching |
| `maxCacheSize` | `int` | 500 MB | Maximum cache size in bytes |
| `cacheExpiration` | `Duration` | 7 days | How long to keep cached files |
| `cacheDirectory` | `String?` | null | Override the local directory used for cached files (defaults to `applicationSupportDirectory/cached`) |

#### Metadata Extraction Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `autoExtractMetadata` | `bool` | true | Enable automatic metadata extraction |
| `autoExtractSha256` | `bool` | false | Compute SHA-256 hash of files |
| `autoExtractThumbnail` | `bool` | false | Generate thumbnails for images/videos/PDFs |
| `autoExtractWaveform` | `bool` | false | Generate waveform data for audio files |
| `thumbnailMaxWidth` | `int` | 200 | Maximum thumbnail width in pixels |
| `thumbnailMaxHeight` | `int` | 200 | Maximum thumbnail height in pixels |
| `waveformSamplesPerSecond` | `int` | 30 | Waveform resolution (samples per second) |

#### Initialize Configuration

```dart
// Initialize with custom settings
TransferKitConfig.init(
  // Transfer settings
  maxConcurrentDownloads: 3,
  maxConcurrentUploads: 2,
  streamCleanupDelay: Duration(seconds: 5),
  enableLogging: true,
  retryAttempts: 5,

  // Cache settings
  cacheEnabled: true,
  maxCacheSize: 1024 * 1024 * 1024, // 1 GB
  cacheExpiration: Duration(days: 30),

  // Metadata extraction settings
  autoExtractMetadata: true,
  autoExtractSha256: true,
  autoExtractThumbnail: true,
  autoExtractWaveform: true,
  thumbnailMaxWidth: 300,
  thumbnailMaxHeight: 300,
  waveformSamplesPerSecond: 50,
);
```

#### Access Configuration at Runtime

```dart
// Get current configuration
final config = TransferKitConfig.instance;
print('Max downloads: ${config.maxConcurrentDownloads}');
print('Cache enabled: ${config.cacheEnabled}');

// Update settings at runtime
config.setMaxConcurrentDownloads(5);
config.setLoggingEnabled(false);
config.setCacheEnabled(true);

// Get all settings as map (useful for debugging)
print(config.toMap());
```

#### Reset Configuration

```dart
// Reset to default values
TransferKitConfig.reset();
```

---

## Media Metadata

The library provides comprehensive metadata extraction and storage for files.

### MediaMetadata Class

Stores detailed metadata for images, videos, audio files, and documents:

```dart
final metadata = MediaMetadata(
  // Common properties
  mimeType: 'image/jpeg',
  fileSize: 1024000,
  fileName: 'photo.jpg',

  // Image/Video dimensions
  width: 1920,
  height: 1080,

  // Video/Audio duration
  durationInSeconds: 120.5,

  // Document properties
  pageCount: 10,
  title: 'Annual Report',
  author: 'John Doe',
);
```

### Using Metadata with Downloads

Pass metadata from your API response when creating download tasks:

```dart
// Download with metadata from API
final task = await fileManager.downloadTask(
  filePathAndUrl: FilePathAndURL.url(
    url: 'https://firebasestorage.googleapis.com/.../image.jpg',
    metadata: MediaMetadata(
      mimeType: 'image/jpeg',
      width: 1920,
      height: 1080,
      fileSize: apiResponse['size'],
    ),
  ),
  taskId: 'download_001',
);
```

### Automatic Metadata Extraction

After download/upload completion, metadata is automatically extracted from the local file and merged with any existing metadata:

```dart
// After download completes, access full metadata
final cachedFile = FilePathAndURLRepository.instance.getByUrl(url);
final metadata = cachedFile?.metadata;

print('Type: ${metadata?.mimeType}');         // image/jpeg
print('Size: ${metadata?.fileSize}');         // 1024000
print('Dimensions: ${metadata?.width}x${metadata?.height}'); // 1920x1080
print('Duration: ${metadata?.duration}');      // For video/audio
print('SHA-256: ${metadata?.sha256}');        // If enabled
print('Page Count: ${metadata?.pageCount}');   // For PDF
```

### Supported File Types

| Type | Extracted Data | Package Used |
|------|----------------|--------------|
| **Images** | Dimensions, EXIF, orientation, alpha, thumbnails | `image` |
| **Videos** | Thumbnails | `video_thumbnail` |
| **Audio** | Duration, waveform visualization | `just_audio`, `just_waveform` |
| **PDF** | Page count, first page thumbnail | `pdfx` |
| **All Files** | MIME type, SHA-256, size, timestamps | `mime`, `crypto` |

### Metadata Sources

Track where metadata came from:

```dart
enum MetadataSource {
  api,      // From backend API response
  firebase, // From Firebase Storage metadata
  cache,    // From local cache
  local,    // Extracted from local file
}
```

### Waveform Data (Audio)

Automatic waveform extraction for audio visualization:

```dart
// Enable waveform extraction in config
TransferKitConfig.init(
  autoExtractWaveform: true,
  waveformSamplesPerSecond: 30, // Samples per second of audio
);

// After audio download, waveform is available
final metadata = cachedFile?.metadata;
final waveform = metadata?.waveform;

print('Samples: ${waveform?.samples.length}');      // e.g., 900 for 30s audio
print('Peak amplitude: ${waveform?.peakAmplitude}'); // 0.0 to 1.0
print('Channels: ${waveform?.channels}');           // 1 (mono) or 2 (stereo)

// Use samples for visualization
CustomPaint(
  painter: WaveformPainter(samples: waveform?.samples ?? []),
)
```

### Thumbnail Data

Automatic thumbnail extraction for images, videos, and PDF documents:

```dart
// Enable thumbnail extraction in config
TransferKitConfig.init(
  autoExtractThumbnail: true,
  thumbnailMaxWidth: 200,
  thumbnailMaxHeight: 200,
);

// After download, thumbnail is available for:
// - Images (resized version)
// - Videos (first frame)
// - PDFs (first page rendered as image)

final thumbnail = metadata?.thumbnail;

// Display thumbnail
if (thumbnail?.bytes != null) {
  Image.memory(thumbnail!.bytes!);
}

// Or use base64 for persistence
final base64 = thumbnail?.base64;
```

---

## Notifications

TransferKit ships with a configurable notification system for transfer
lifecycle events. **Notifications are disabled by default** (opt-in) to
avoid surprising existing apps. Enable them by passing a
`TransferNotificationConfig` to `TransferKitConfig.init`.

### Quick start

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(
    enabled: true,
    // Defaults: progress on, completion on, errors on,
    // cancelled/paused/retry off, throttle 1 s, perFile grouping.
  ),
);

// Optionally request OS permission at a moment of your choosing.
await TransferKit.instance.requestNotificationPermission();
```

### Suppress upload notifications, allow downloads

```dart
notificationConfig: const TransferNotificationConfig(
  enabled: true,
  uploadEnabled: false,
  downloadEnabled: true,
),
```

### Show only completion and error notifications

```dart
notificationConfig: const TransferNotificationConfig(
  enabled: true,
  showProgress: false,
  showCompletion: true,
  showErrors: true,
),
```

### Custom templates per direction

```dart
notificationConfig: TransferNotificationConfig(
  enabled: true,
  uploadTemplate: const TransferNotificationTemplate(
    title: 'Sending file…',
    successText: 'File sent',
  ),
  downloadTemplate: const TransferNotificationTemplate(
    title: 'Receiving file…',
    successText: 'File ready',
  ),
),
```

Templates also support a `localization` map and a `resolveText(key, payload)`
callback for full developer control (route through your app's `intl` system,
emit ICU plurals, etc.).

### Throttle progress updates

```dart
notificationConfig: const TransferNotificationConfig(
  enabled: true,
  throttleDuration: Duration(seconds: 3),
),
```

### Group multi-file transfers into one notification

```dart
notificationConfig: const TransferNotificationConfig(
  enabled: true,
  grouping: NotificationGroupingMode.batch,
),
```

A 5-file batch upload now produces exactly one grouped notification
summarising overall progress.

### Replace the built-in adapter

```dart
class MyAdapter implements TransferNotificationAdapter { /* ... */ }

notificationConfig: TransferNotificationConfig(
  enabled: true,
  adapter: MyAdapter(),
),
```

The built-in `AwesomeNotificationAdapter` is the default when `adapter` is
null and `enabled: true`. The `awesome_notifications` import lives in that
single file — no other part of TransferKit references the package.

### Permission API

```dart
final status = await TransferKit.instance.checkNotificationPermission();
// returns granted / denied / restricted / notDetermined.
// `checkNotificationPermission` never shows a system dialog.
```

`requestNotificationPermission()` may show a dialog. TransferKit never auto-
requests permission unless you set `requestPermissionOnInit: true` on the
config.

### Platform support

| Platform | Behavior                                                          |
|----------|-------------------------------------------------------------------|
| Android  | Full support. Channel registered lazily on first notification.    |
| iOS      | Full support. Permission must be requested before first notif.    |
| macOS    | Notification methods silently no-op. Permission `notDetermined`.  |
| Windows  | Notification methods silently no-op. Permission `notDetermined`.  |
| Linux    | Notification methods silently no-op. Permission `notDetermined`.  |
| Web      | Notification methods silently no-op. Permission `notDetermined`.  |

### Migration from previous versions

Earlier releases rendered notifications automatically through
`BackgroundTransferService`. That coupling has been removed — to restore the
old behavior, opt in:

```dart
await TransferKitConfig.init(
  driver: HttpDownloadDriver(),
  notificationConfig: const TransferNotificationConfig(enabled: true),
);
```

### Testing with `FakeNotificationAdapter`

Use `FakeNotificationAdapter` (in `test/src/notification/fake/`) as a hand-
written test double — every adapter call is recorded with method name,
payload, and timestamp.

---

## Exception Classes

The library provides typed exceptions for better error handling:

| Exception | Description |
|-----------|-------------|
| `FileException` | Base class for all file exceptions |
| `FileDownloadException` | Download operation failed |
| `FileUploadException` | Upload operation failed |
| `FileDeleteException` | File deletion failed |
| `FileCacheException` | Cache operation failed |
| `FileTaskException` | Task operation (pause/resume/cancel) failed |

All exceptions support error chaining:

```dart
class FileException implements Exception {
  final String message;
  final Object? cause;        // Original exception
  final StackTrace? stackTrace;
}
```

---

## Extension Methods

Useful extensions included with the package:

```dart
// File path extensions
'path/to/file.pdf'.fileName        // 'file.pdf'
'path/to/file.pdf'.extension       // 'pdf'
'some-url'.toHashName()            // Hashed filename for caching

// Number formatting
1500000.formatBytes                // '1.5 MB'

// String utilities
jsonString.toListMap()             // Parse JSON to List<Map>
'https://...'.isURL                // true
```

---

## Dependencies

### Core Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_storage: ^12.0.0
  cloud_firestore: ^5.0.0
  get_storage: ^2.1.1
  path_provider: ^2.1.0
  collection: ^1.18.0
  logger: ^2.0.0
```

### Metadata Extraction (Optional)

```yaml
  # File identification
  crypto: ^3.0.0              # SHA-256 hash computation
  mime: ^1.0.0                # MIME type detection

  # Media metadata
  image: ^4.0.0               # Image dimensions, EXIF, thumbnails
  video_thumbnail: ^0.5.0     # Video thumbnail extraction
  just_audio: ^0.9.0          # Audio duration
  just_waveform: ^0.0.7       # Audio waveform generation
  pdfx: ^2.0.0                # PDF page count and thumbnails
```

### UI Widgets

```yaml
  cached_network_image: ^3.4.1
  carousel_slider: ^5.0.0     # Image carousel
  dashed_circular_progress_bar: ^0.0.6
```

---

## Migration Guide

### From v1.x to v2.x

The v2.x release of TransferKit introduces stream sharing and centralized configuration. Existing code continues to work without changes, but you can now benefit from:

1. **Automatic Stream Sharing** — No code changes needed, multiple widgets share streams
2. **Centralized Configuration** — Use `TransferKitConfig.init()` to customize behavior
3. **New Exception Classes** — Add error chaining with `cause` and `stackTrace`
4. **Stream Statistics** — Monitor resource usage with `getActiveStreamStats()`

#### New Features

```dart
// New: Centralized configuration
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

// New: Stream statistics
final stats = FirebaseStorageFactory.getActiveStreamStats();
```

---

## Contributing

Contributions are welcome! Please read our contributing guidelines before submitting pull requests.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with Flutter
</p>
