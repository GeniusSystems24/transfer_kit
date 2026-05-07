import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/extension/file_path_extension.dart';
import '../repository/file_path_and_url_repository.dart';
import '../model/file_model.dart';
import 'file_task_controller.dart';
import 'media_download_card.dart';
import 'utils/hero_card.dart';
import 'utils/media_constants.dart';

/// Widget to display an image attachment with download support.
///
/// Automatically handles downloading from URL and caching locally.
class DownloadImageWidget extends StatelessWidget {
  /// File model containing image data
  final FileModel file;

  final String? heroTag;

  final void Function(BuildContext context, String filePath)? onTap;

  final bool autoStart;
  final Widget Function(BuildContext context, String filePath)? itemBuilder;

  final double? aspectRatio;
  final double defaultAspectRatio;
  final bool showActionButton;

  final ImageProvider? thumbnailProvider;

  final double scale;
  final Widget Function(BuildContext, Widget, int?, bool)? frameBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final double? width;
  final double? height;
  final Color? color;
  final Animation<double>? opacity;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final bool gaplessPlayback;
  final bool isAntiAlias;
  final FilterQuality filterQuality;
  final int? cacheWidth;
  final int? cacheHeight;
  final bool isCircle;
  final bool showInDialog;
  final Widget Function(BuildContext context)? emptyBuilder;

  /// Creates a DownloadImageWidget
  const DownloadImageWidget({
    super.key,
    required this.file,
    this.heroTag,
    this.onTap,
    this.itemBuilder,
    this.aspectRatio,
    this.defaultAspectRatio = 1,
    this.showActionButton = true,
    this.scale = 1.0,
    this.frameBuilder,
    this.errorBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.opacity,
    this.colorBlendMode,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
    this.gaplessPlayback = false,
    this.isAntiAlias = false,
    this.filterQuality = FilterQuality.medium,
    this.cacheWidth,
    this.cacheHeight,
    this.isCircle = false,
    this.showInDialog = false,
    this.thumbnailProvider,
    this.emptyBuilder,
    this.autoStart = false,
  });

  /// URL of the image if available
  String? get url => file.url;

  /// Local path of the image if available
  String? get localPath => file.localPath;

  /// Thumbnail data if available
  Uint8List? get thumbnail => file.thumbnail;

  /// Hero tag for animation
  String? get _heroTag => heroTag ?? file.fileName ?? file.localPath;

  /// Whether the image has a valid source
  bool get hasValidSource => localPath != null || url != null;

  double get _aspectRatio =>
      aspectRatio ?? file.aspectRatio ?? defaultAspectRatio;

  @override
  Widget build(BuildContext context) {
    var child = _buildImageContent(context);
    if (heroTag != null) child = HeroCard(tag: heroTag!, child: child);
    if (itemBuilder == null) {
      child = AspectRatio(aspectRatio: _aspectRatio, child: child);
    }
    if (isCircle) child = ClipOval(child: child);
    return child;
  }

  /// Builds the appropriate image content based on available sources
  Widget _buildImageContent(BuildContext context) {
    if (localPath != null) return _itemBuild(context, localPath!);

    final cachePath = FilePathAndURLRepository.instance.getByUrl(file.url!);
    if (cachePath != null) return _itemBuild(context, cachePath.path);

    final downloadTask = DownloadTask(
      url: file.url!,
      allowPause: true,
      updates: Updates.statusAndProgress,
      directory: '',
      baseDirectory: BaseDirectory.temporary,
      filename: file.url!.toHashName(),
    );

    return FutureBuilder(
      future: FileTaskController.instance.enqueueOrResume(
        downloadTask,
        autoStart,
      ),
      builder: (context, asyncSnapshot) {
        final (String? filePath, StreamController<TaskItem>? streamController) =
            asyncSnapshot.data ?? (null, null);

        if (filePath != null) return _itemBuild(context, filePath);

        final thumbnail = file.thumbnail;

        return StreamBuilder(
          initialData:
              FileTaskController.instance.fileUpdates[downloadTask.url],
          stream:
              (streamController ??
                      FileTaskController.instance.createFileController(
                        downloadTask.url,
                      ))
                  .stream,
          builder: (context, asyncSnapshot) {
            var taskItem = asyncSnapshot.data;
            return MediaDownloadCard(
              item: taskItem,
              isVideo: false,
              showActionButton: showActionButton,
              onStart: () => FileTaskController.instance.fileDownloader.enqueue(
                downloadTask,
              ),
              onPause: (item) => FileTaskController.instance.pause(item),
              onResume: (item) => FileTaskController.instance.resume(item),
              onCancel: (item) => FileTaskController.instance.cancel(item),
              onRetry: (item) => FileTaskController.instance.retry(item),
              completedBuilder: (context, item) =>
                  _itemBuild(context, item.filePath),
              thumbnailProvider: thumbnail != null
                  ? MemoryImage(thumbnail)
                  : thumbnailProvider,
              emptyBuilder: emptyBuilder,
              thumbnailFit: fit ?? BoxFit.cover,
            );
          },
        );
      },
    );
  }

  Widget _itemBuild(BuildContext context, String filePath) {
    return itemBuilder?.call(context, filePath) ??
        GestureDetector(
          onTap: () {
            if (onTap != null) {
              onTap!(context, filePath);
            } else {
              showInDialog
                  ? _showFullScreenImageInDialog(context, filePath)
                  : _showFullScreenImage(context, filePath);
            }
          },
          child: Image.file(
            File(filePath),
            fit: fit,
            width: width,
            height: height,
            color: color,
            opacity: opacity,
            colorBlendMode: colorBlendMode,
            errorBuilder:
                errorBuilder ??
                (context, error, stackTrace) => const _ImageErrorWidget(),
            frameBuilder: frameBuilder,
            semanticLabel: semanticLabel,
            excludeFromSemantics: excludeFromSemantics,
            gaplessPlayback: gaplessPlayback,
            isAntiAlias: isAntiAlias,
            filterQuality: filterQuality,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            alignment: alignment,
            repeat: repeat,
            centerSlice: centerSlice,
            matchTextDirection: matchTextDirection,
            scale: scale,
          ),
        );
  }

  /// Shows the image in full-screen mode with zoom capabilities
  void _showFullScreenImage(BuildContext context, String filePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ImageViewerFullScreen(filePath: filePath, heroTag: _heroTag),
      ),
    );
  }

  /// Shows the image in full-screen mode with zoom capabilities
  void _showFullScreenImageInDialog(BuildContext context, String filePath) {
    showDialog(
      context: context,
      builder: (context) {
        Widget child = Image.file(File(filePath));
        if (heroTag != null) child = HeroCard(tag: heroTag!, child: child);
        return Dialog(
          child: Card(
            child: InkWell(
              onTap: () {
                Navigator.pop(context);
                _showFullScreenImage(context, filePath);
              },
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Widget displayed when image fails to load
class _ImageErrorWidget extends StatelessWidget {
  const _ImageErrorWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: theme.colorScheme.error),
          const SizedBox(height: ImageBubbleConstants.errorSpacing),
          Text(
            'Image not available',
            style: TextStyle(color: theme.colorScheme.onError, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Full screen image viewer with zoom and pan support
class ImageViewerFullScreen extends StatelessWidget {
  final String filePath;
  final String? heroTag;

  const ImageViewerFullScreen({
    super.key,
    required this.filePath,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.file(File(filePath), fit: BoxFit.contain),
    );

    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: image),
    );
  }
}
