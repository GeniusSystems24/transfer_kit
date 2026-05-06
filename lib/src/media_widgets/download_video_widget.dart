import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/extension/file_path_extension.dart';
import '../repository/file_path_and_url_repository.dart';
import '../model/file_model.dart';
import 'file_task_controller.dart';
import 'media_download_card.dart';
import 'utils/hero_card.dart';
import 'utils/media_constants.dart';

/// Widget to display a video attachment with download support.
///
/// Automatically handles downloading from URL and caching locally.
/// Provides thumbnail preview with play button overlay.
class DownloadVideoWidget extends StatefulWidget {
  /// File model containing video data
  final FileModel file;

  /// Key for video controller management
  final String keyController;

  /// Hero tag for hero animations
  final String? heroTag;

  /// Callback when video is tapped
  final void Function(BuildContext context, String filePath)? onTap;

  /// Whether to auto-start download
  final bool autoStart;

  /// Custom item builder for completed state
  final Widget Function(BuildContext context, String filePath)? itemBuilder;

  /// Default aspect ratio if not available from file
  final double defaultAspectRatio;

  /// Creates a DownloadVideoWidget
  const DownloadVideoWidget({
    super.key,
    required this.file,
    required this.keyController,
    this.heroTag,
    this.onTap,
    this.autoStart = true,
    this.itemBuilder,
    this.defaultAspectRatio = 16 / 9,
  });

  /// URL of the video if available
  String? get url => file.url;

  /// Local path of the video if available
  String? get localPath => file.localPath;

  /// Thumbnail data if available
  Uint8List? get thumbnail => file.thumbnail;

  /// Duration of the video in seconds
  int get duration => file.durationInSeconds ?? 0;

  /// File size in bytes
  int get fileSize => file.size ?? 0;

  /// Whether the video has a valid source
  bool get hasValidSource => localPath != null || url != null;

  /// Gets formatted file size
  String get formattedFileSize => formatFileSize(fileSize);

  /// Gets formatted duration
  String get formattedDuration => formatDuration(duration);

  @override
  State<DownloadVideoWidget> createState() => _DownloadVideoWidgetState();
}

class _DownloadVideoWidgetState extends State<DownloadVideoWidget>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var child = _buildVideoContent(context);
    if (widget.itemBuilder == null) {
      child = AspectRatio(
        aspectRatio: widget.file.aspectRatio ?? widget.defaultAspectRatio,
        child: child,
      );
    }
    return child;
  }

  /// Builds the appropriate video content based on state
  Widget _buildVideoContent(BuildContext context) {
    // If we have a local file or cached file, show thumbnail with tap to play
    if (widget.localPath != null) {
      return _videoPlayerBuild(context, widget.localPath!);
    }

    final cachePath = FilePathAndURLRepository.instance.getByUrl(
      widget.file.url!,
    );
    if (cachePath != null) return _videoPlayerBuild(context, cachePath.path);

    final downloadTask = DownloadTask(
      url: widget.file.url!,
      allowPause: true,
      updates: Updates.statusAndProgress,
      directory: '',
      baseDirectory: BaseDirectory.temporary,
      filename: widget.file.url!.toHashName(),
    );

    return FutureBuilder(
      future: FileTaskController.instance.enqueueOrResume(downloadTask, false),
      builder: (context, asyncSnapshot) {
        final (String? filePath, StreamController<TaskItem>? streamController) =
            asyncSnapshot.data ?? (null, null);

        if (filePath != null) return _videoPlayerBuild(context, filePath);

        final thumbnail = widget.thumbnail;

        return StreamBuilder(
          initialData:
              FileTaskController.instance.fileUpdates[downloadTask.url],
          stream: (streamController ??
                  FileTaskController.instance.createFileController(
                    downloadTask.url,
                  ))
              .stream,
          builder: (context, asyncSnapshot) {
            var taskItem = asyncSnapshot.data;
            return MediaDownloadCard(
              item: taskItem,
              isVideo: true,
              onStart: () => FileTaskController.instance.fileDownloader.enqueue(
                downloadTask,
              ),
              onPause: (item) => FileTaskController.instance.pause(item),
              onResume: (item) => FileTaskController.instance.resume(item),
              onCancel: (item) => FileTaskController.instance.cancel(item),
              onRetry: (item) => FileTaskController.instance.retry(item),
              completedBuilder: (context, item) =>
                  _videoPlayerBuild(context, item.filePath),
              thumbnailProvider:
                  thumbnail != null ? MemoryImage(thumbnail) : null,
            );
          },
        );
      },
    );
  }

  Widget _videoPlayerBuild(BuildContext context, String filePath) {
    if (widget.itemBuilder != null) {
      return widget.itemBuilder!(context, filePath);
    }

    // Default video preview with thumbnail and play button
    Widget child = VideoPreviewWidget(
      filePath: filePath,
      thumbnail: widget.thumbnail,
      duration: widget.formattedDuration,
      fileSize: widget.formattedFileSize,
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!(context, filePath);
        }
      },
    );

    if (widget.heroTag != null) {
      return HeroCard(tag: widget.heroTag!, child: child);
    }
    return child;
  }
}

/// Simple video preview widget with thumbnail and play button
class VideoPreviewWidget extends StatelessWidget {
  final String filePath;
  final Uint8List? thumbnail;
  final String duration;
  final String fileSize;
  final VoidCallback? onTap;

  const VideoPreviewWidget({
    super.key,
    required this.filePath,
    this.thumbnail,
    this.duration = '',
    this.fileSize = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail or placeholder
          if (thumbnail != null)
            Image.memory(
              thumbnail!,
              fit: BoxFit.cover,
            )
          else
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.video_file,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),

          // Overlay
          Container(
            color: Colors.black.withValues(alpha: 0.3),
          ),

          // Play button
          Center(
            child: Container(
              width: VideoBubbleConstants.playButtonSize,
              height: VideoBubbleConstants.playButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.9),
              ),
              child: Icon(
                Icons.play_arrow,
                size: VideoBubbleConstants.playIconSize,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),

          // Duration badge
          if (duration.isNotEmpty)
            Positioned(
              bottom: VideoBubbleConstants.durationPadding,
              right: VideoBubbleConstants.durationPadding,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VideoBubbleConstants.durationPadding,
                  vertical: VideoBubbleConstants.durationVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(
                    VideoBubbleConstants.durationBorderRadius,
                  ),
                ),
                child: Text(
                  duration,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: VideoBubbleConstants.durationFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // File size badge
          if (fileSize.isNotEmpty)
            Positioned(
              bottom: VideoBubbleConstants.durationPadding,
              left: VideoBubbleConstants.durationPadding,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: VideoBubbleConstants.durationPadding,
                  vertical: VideoBubbleConstants.durationVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(
                    VideoBubbleConstants.durationBorderRadius,
                  ),
                ),
                child: Text(
                  fileSize,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: VideoBubbleConstants.durationFontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Helper function to format duration
String formatDuration(int seconds) {
  if (seconds <= 0) return '';

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;

  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  } else {
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

/// Helper function to format file size
String formatFileSize(int bytes) {
  if (bytes <= 0) return '';

  const suffixes = ['B', 'KB', 'MB', 'GB'];
  var i = 0;
  double size = bytes.toDouble();

  while (size >= 1024 && i < suffixes.length - 1) {
    size /= 1024;
    i++;
  }

  return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
}
