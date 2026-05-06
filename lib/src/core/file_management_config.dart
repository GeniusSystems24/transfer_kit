import '../../transfer_kit.dart';

/// Configuration class for the File Management System.
///
/// This singleton class provides centralized configuration for all file
/// management operations including uploads, downloads, caching, and logging.
///
/// ## Usage
///
/// Initialize the configuration early in your app (typically in `main()`):
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Configure the file management system
///   TransferKitConfig.init(
///     maxConcurrentDownloads: 3,
///     maxConcurrentUploads: 2,
///     streamCleanupDelay: Duration(seconds: 5),
///     enableLogging: true,
///   );
///
///   // Initialize app directories
///   await FilePathExtension.initAppDirectory();
///
///   runApp(MyApp());
/// }
/// ```
///
/// ## Default Values
///
/// | Setting | Default | Description |
/// |---------|---------|-------------|
/// | `maxConcurrentDownloads` | 5 | Maximum simultaneous downloads |
/// | `maxConcurrentUploads` | 3 | Maximum simultaneous uploads |
/// | `streamCleanupDelay` | 3 seconds | Delay before cleaning unused streams |
/// | `defaultAutoStart` | true | Auto-start transfers by default |
/// | `enableLogging` | false | Enable debug logging |
/// | `retryAttempts` | 3 | Number of retry attempts on failure |
/// | `retryDelay` | 2 seconds | Delay between retry attempts |
///
/// ## Accessing Configuration
///
/// ```dart
/// // Get current configuration
/// final config = TransferKitConfig.instance;
/// print('Max downloads: ${config.maxConcurrentDownloads}');
///
/// // Check if logging is enabled
/// if (TransferKitConfig.instance.enableLogging) {
///   print('Debug mode is ON');
/// }
/// ```
class TransferKitConfig {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════════════════

  static TransferKitConfig? _instance;

  /// Gets the singleton instance of [TransferKitConfig].
  ///
  /// If [init] has not been called, returns an instance with default values.
  static TransferKitConfig get instance {
    _instance ??= TransferKitConfig._internal();
    return _instance!;
  }

  /// Private constructor for singleton pattern.
  TransferKitConfig._internal();

  // constructor
  TransferKitConfig({
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
    // Metadata settings
    bool? autoExtractMetadata,
    bool? autoExtractSha256,
    bool? autoExtractThumbnail,
    bool? autoExtractWaveform,
    int? thumbnailMaxWidth,
    int? thumbnailMaxHeight,
    int? waveformSamplesPerSecond,
  })  : _maxConcurrentDownloads = maxConcurrentDownloads ?? 5,
        _maxConcurrentUploads = maxConcurrentUploads ?? 3,
        _streamCleanupDelay = streamCleanupDelay ?? const Duration(seconds: 3),
        _defaultAutoStart = defaultAutoStart ?? true,
        _enableLogging = enableLogging ?? false,
        _retryAttempts = retryAttempts ?? 3,
        _retryDelay = retryDelay ?? const Duration(seconds: 2),
        _cacheEnabled = cacheEnabled ?? true,
        _maxCacheSize = maxCacheSize ?? (500 * 1024 * 1024), // 500 MB
        _cacheExpiration = cacheExpiration ?? const Duration(days: 7),
        _autoExtractMetadata = autoExtractMetadata ?? true,
        _autoExtractSha256 = autoExtractSha256 ?? false,
        _autoExtractThumbnail = autoExtractThumbnail ?? false,
        _autoExtractWaveform = autoExtractWaveform ?? false,
        _thumbnailMaxWidth = thumbnailMaxWidth ?? 200,
        _thumbnailMaxHeight = thumbnailMaxHeight ?? 200,
        _waveformSamplesPerSecond = waveformSamplesPerSecond ?? 30;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initializes the file management configuration.
  ///
  /// Call this method early in your app startup to configure the library.
  /// All parameters are optional and will use sensible defaults if not provided.
  ///
  /// ## Parameters
  ///
  /// * [maxConcurrentDownloads] - Maximum number of simultaneous downloads (default: 5)
  /// * [maxConcurrentUploads] - Maximum number of simultaneous uploads (default: 3)
  /// * [streamCleanupDelay] - Delay before cleaning up unused streams (default: 3 seconds)
  /// * [defaultAutoStart] - Whether transfers start automatically (default: true)
  /// * [enableLogging] - Enable debug logging (default: false in release, true in debug)
  /// * [retryAttempts] - Number of retry attempts on failure (default: 3)
  /// * [retryDelay] - Delay between retry attempts (default: 2 seconds)
  /// * [cacheEnabled] - Enable file caching (default: true)
  /// * [maxCacheSize] - Maximum cache size in bytes (default: 500 MB)
  /// * [cacheExpiration] - How long to keep cached files (default: 7 days)
  ///
  /// ## Example
  ///
  /// ```dart
  /// TransferKitConfig.init(
  ///   maxConcurrentDownloads: 3,
  ///   maxConcurrentUploads: 2,
  ///   streamCleanupDelay: Duration(seconds: 5),
  ///   enableLogging: kDebugMode,
  ///   retryAttempts: 5,
  ///   cacheEnabled: true,
  ///   maxCacheSize: 1024 * 1024 * 1024, // 1 GB
  /// );
  /// ```
  static Future<void> init({
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
    // Metadata settings
    bool? autoExtractMetadata,
    bool? autoExtractSha256,
    bool? autoExtractThumbnail,
    bool? autoExtractWaveform,
    int? thumbnailMaxWidth,
    int? thumbnailMaxHeight,
    int? waveformSamplesPerSecond,
  }) async {
    await GetStorage.init();
    _instance = TransferKitConfig._internal()
      .._maxConcurrentDownloads = maxConcurrentDownloads ?? 5
      .._maxConcurrentUploads = maxConcurrentUploads ?? 3
      .._streamCleanupDelay = streamCleanupDelay ?? const Duration(seconds: 3)
      .._defaultAutoStart = defaultAutoStart ?? true
      .._enableLogging = enableLogging ?? false
      .._retryAttempts = retryAttempts ?? 3
      .._retryDelay = retryDelay ?? const Duration(seconds: 2)
      .._cacheEnabled = cacheEnabled ?? true
      .._maxCacheSize = maxCacheSize ?? (500 * 1024 * 1024) // 500 MB
      .._cacheExpiration = cacheExpiration ?? const Duration(days: 7)
      // Metadata settings
      .._autoExtractMetadata = autoExtractMetadata ?? true
      .._autoExtractSha256 = autoExtractSha256 ?? false
      .._autoExtractThumbnail = autoExtractThumbnail ?? false
      .._autoExtractWaveform = autoExtractWaveform ?? false
      .._thumbnailMaxWidth = thumbnailMaxWidth ?? 200
      .._thumbnailMaxHeight = thumbnailMaxHeight ?? 200
      .._waveformSamplesPerSecond = waveformSamplesPerSecond ?? 30;

    await AppDirectory.init();
    
  }

  /// Resets the configuration to default values.
  ///
  /// Useful for testing or when you need to reinitialize the configuration.
  static void reset() {
    _instance = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONCURRENCY SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  int _maxConcurrentDownloads = 5;
  int _maxConcurrentUploads = 3;

  /// Maximum number of simultaneous download operations.
  ///
  /// Downloads beyond this limit will be queued.
  /// Default: 5
  int get maxConcurrentDownloads => _maxConcurrentDownloads;

  /// Maximum number of simultaneous upload operations.
  ///
  /// Uploads beyond this limit will be queued.
  /// Default: 3
  int get maxConcurrentUploads => _maxConcurrentUploads;

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAM SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  Duration _streamCleanupDelay = const Duration(seconds: 3);

  /// Delay before cleaning up unused shared streams.
  ///
  /// This prevents rapid cleanup/recreation of streams during widget rebuilds.
  /// A longer delay reduces resource churn but uses more memory.
  /// Default: 3 seconds
  Duration get streamCleanupDelay => _streamCleanupDelay;

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSFER SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _defaultAutoStart = true;

  /// Whether file transfers start automatically by default.
  ///
  /// If false, transfers must be explicitly started.
  /// Default: true
  bool get defaultAutoStart => _defaultAutoStart;

  // ═══════════════════════════════════════════════════════════════════════════
  // RETRY SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  int _retryAttempts = 3;
  Duration _retryDelay = const Duration(seconds: 2);

  /// Number of retry attempts when a transfer fails.
  ///
  /// Set to 0 to disable automatic retries.
  /// Default: 3
  int get retryAttempts => _retryAttempts;

  /// Delay between retry attempts.
  ///
  /// Uses exponential backoff: delay * (2 ^ attemptNumber)
  /// Default: 2 seconds
  Duration get retryDelay => _retryDelay;

  // ═══════════════════════════════════════════════════════════════════════════
  // CACHE SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _cacheEnabled = true;
  int _maxCacheSize = 500 * 1024 * 1024; // 500 MB
  Duration _cacheExpiration = const Duration(days: 7);

  /// Whether file caching is enabled.
  ///
  /// When enabled, downloaded files are cached locally to avoid
  /// redundant downloads.
  /// Default: true
  bool get cacheEnabled => _cacheEnabled;

  /// Maximum cache size in bytes.
  ///
  /// When the cache exceeds this size, oldest files are removed.
  /// Default: 500 MB (524,288,000 bytes)
  int get maxCacheSize => _maxCacheSize;

  /// How long to keep cached files before they expire.
  ///
  /// Expired files are removed during cleanup operations.
  /// Default: 7 days
  Duration get cacheExpiration => _cacheExpiration;

  // ═══════════════════════════════════════════════════════════════════════════
  // LOGGING SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _enableLogging = false;

  /// Whether debug logging is enabled.
  ///
  /// When enabled, detailed logs are printed for debugging.
  /// Default: false
  bool get enableLogging => _enableLogging;

  // ═══════════════════════════════════════════════════════════════════════════
  // METADATA EXTRACTION SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _autoExtractMetadata = true;
  bool _autoExtractSha256 = false;
  bool _autoExtractThumbnail = false;
  bool _autoExtractWaveform = false;
  int _thumbnailMaxWidth = 200;
  int _thumbnailMaxHeight = 200;
  int _waveformSamplesPerSecond = 30;

  /// Whether to automatically extract metadata from files after download/upload.
  ///
  /// When enabled, basic metadata (dimensions, MIME type, file size) is extracted.
  /// Default: true
  bool get autoExtractMetadata => _autoExtractMetadata;

  /// Whether to compute SHA-256 hash during metadata extraction.
  ///
  /// This is disabled by default as it requires reading the entire file
  /// and can be slow for large files.
  /// Default: false
  bool get autoExtractSha256 => _autoExtractSha256;

  /// Whether to automatically generate thumbnails for images/videos.
  ///
  /// This is disabled by default as it requires additional processing
  /// and may need external packages.
  /// Default: false
  bool get autoExtractThumbnail => _autoExtractThumbnail;

  /// Whether to automatically generate waveform data for audio files.
  ///
  /// This is disabled by default as it requires significant processing
  /// and increases storage size.
  /// Default: false
  bool get autoExtractWaveform => _autoExtractWaveform;

  /// Maximum width for generated thumbnails in pixels.
  ///
  /// Default: 200
  int get thumbnailMaxWidth => _thumbnailMaxWidth;

  /// Maximum height for generated thumbnails in pixels.
  ///
  /// Default: 200
  int get thumbnailMaxHeight => _thumbnailMaxHeight;

  /// Number of waveform samples per second for audio files.
  ///
  /// Higher values provide more detail but increase storage size.
  /// Default: 30
  int get waveformSamplesPerSecond => _waveformSamplesPerSecond;

  // ═══════════════════════════════════════════════════════════════════════════
  // RUNTIME UPDATES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Updates the maximum concurrent downloads at runtime.
  ///
  /// Note: This only affects new transfers, not ones already in progress.
  void setMaxConcurrentDownloads(int value) {
    if (value < 1) {
      throw ArgumentError('maxConcurrentDownloads must be at least 1');
    }
    _maxConcurrentDownloads = value;
  }

  /// Updates the maximum concurrent uploads at runtime.
  ///
  /// Note: This only affects new transfers, not ones already in progress.
  void setMaxConcurrentUploads(int value) {
    if (value < 1) {
      throw ArgumentError('maxConcurrentUploads must be at least 1');
    }
    _maxConcurrentUploads = value;
  }

  /// Enables or disables logging at runtime.
  void setLoggingEnabled(bool enabled) {
    _enableLogging = enabled;
  }

  /// Enables or disables caching at runtime.
  void setCacheEnabled(bool enabled) {
    _cacheEnabled = enabled;
  }

  /// Enables or disables automatic metadata extraction at runtime.
  void setAutoExtractMetadata(bool enabled) {
    _autoExtractMetadata = enabled;
  }

  /// Enables or disables SHA-256 hash computation at runtime.
  void setAutoExtractSha256(bool enabled) {
    _autoExtractSha256 = enabled;
  }

  /// Enables or disables automatic thumbnail generation at runtime.
  void setAutoExtractThumbnail(bool enabled) {
    _autoExtractThumbnail = enabled;
  }

  /// Enables or disables automatic waveform generation at runtime.
  void setAutoExtractWaveform(bool enabled) {
    _autoExtractWaveform = enabled;
  }

  /// Updates the thumbnail maximum dimensions at runtime.
  void setThumbnailMaxSize({int? width, int? height}) {
    if (width != null && width > 0) _thumbnailMaxWidth = width;
    if (height != null && height > 0) _thumbnailMaxHeight = height;
  }

  /// Updates the waveform samples per second at runtime.
  void setWaveformSamplesPerSecond(int samples) {
    if (samples > 0) _waveformSamplesPerSecond = samples;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG INFO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns a map of all current configuration values.
  ///
  /// Useful for debugging and logging.
  Map<String, dynamic> toMap() {
    return {
      'maxConcurrentDownloads': _maxConcurrentDownloads,
      'maxConcurrentUploads': _maxConcurrentUploads,
      'streamCleanupDelay': _streamCleanupDelay.inMilliseconds,
      'defaultAutoStart': _defaultAutoStart,
      'enableLogging': _enableLogging,
      'retryAttempts': _retryAttempts,
      'retryDelay': _retryDelay.inMilliseconds,
      'cacheEnabled': _cacheEnabled,
      'maxCacheSize': _maxCacheSize,
      'cacheExpiration': _cacheExpiration.inDays,
      // Metadata settings
      'autoExtractMetadata': _autoExtractMetadata,
      'autoExtractSha256': _autoExtractSha256,
      'autoExtractThumbnail': _autoExtractThumbnail,
      'autoExtractWaveform': _autoExtractWaveform,
      'thumbnailMaxWidth': _thumbnailMaxWidth,
      'thumbnailMaxHeight': _thumbnailMaxHeight,
      'waveformSamplesPerSecond': _waveformSamplesPerSecond,
    };
  }

  @override
  String toString() {
    return 'TransferKitConfig(${toMap()})';
  }
}
