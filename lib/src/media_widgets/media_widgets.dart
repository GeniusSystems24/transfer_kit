/// Media Widgets for File Management System
///
/// This module provides pre-built widgets for downloading and displaying
/// media files (images, videos, documents) with automatic caching support.
///
/// ## Main Widgets
///
/// - [DownloadImageWidget] - Image display with download support
/// - [DownloadVideoWidget] - Video display with thumbnail preview
/// - [DownloadImageSliderWidget] - Carousel for multiple images
/// - [MediaDownloadCard] - Generic download progress card
/// - [DocumentDownloadCard] - Document-specific download card
///
/// ## Usage
///
/// ```dart
/// import 'package:transfer_kit/transfer_kit.dart';
///
/// // Display a downloadable image
/// DownloadImageWidget(
///   file: FileModel(url: 'https://example.com/image.jpg'),
///   autoStart: true,
/// )
///
/// // Display a downloadable video
/// DownloadVideoWidget(
///   file: FileModel(url: 'https://example.com/video.mp4'),
///   keyController: 'video_123',
/// )
/// ```
library;

// Core controller
export 'file_task_controller.dart';

// Download widgets
export 'download_image_widget.dart';
export 'download_video_widget.dart';
export 'download_image_slider_widget.dart';

// Card widgets
export 'media_download_card.dart';
export 'document_download_card.dart';

// Utilities
export 'utils/hero_card.dart';
export 'utils/map_notifier.dart';
export 'utils/media_constants.dart' hide VideoBubbleConstants;
export 'utils/media_progress_indicator.dart';
