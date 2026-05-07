import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../model/file_model.dart';
import 'download_image_widget.dart';
import 'utils/media_progress_indicator.dart';

/// Widget to display multiple images in a carousel/slider with download support.
///
/// Each image is wrapped in a [DownloadImageWidget] for automatic downloading.
class DownloadImageSliderWidget extends StatefulWidget {
  /// Height of the carousel
  final double? height;

  /// List of file models for images to display
  final List<FileModel>? imageFiles;

  /// Border radius for the carousel container
  final double radius;

  /// Callback when an image is tapped
  final void Function(FileModel file)? onImageTap;

  /// Whether to auto-start downloads
  final bool autoStart;

  /// Default aspect ratio for images
  final double defaultAspectRatio;

  /// Whether to show action buttons on images
  final bool showActionButton;

  /// Whether to enable auto-play
  final bool autoPlay;

  /// Auto-play interval duration
  final Duration autoPlayInterval;

  /// Creates a DownloadImageSliderWidget
  const DownloadImageSliderWidget({
    super.key,
    this.height,
    required this.imageFiles,
    this.radius = 16.0,
    this.onImageTap,
    this.autoStart = true,
    this.defaultAspectRatio = 1,
    this.showActionButton = true,
    this.autoPlay = false,
    this.autoPlayInterval = const Duration(seconds: 4),
  });

  @override
  State<DownloadImageSliderWidget> createState() =>
      _DownloadImageSliderWidgetState();
}

class _DownloadImageSliderWidgetState extends State<DownloadImageSliderWidget> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImages = widget.imageFiles?.isNotEmpty ?? false;
    final imageCount = widget.imageFiles?.length ?? 0;
    final showIndicator = imageCount > 1;

    return AspectRatio(
      aspectRatio: widget.defaultAspectRatio,
      child: Container(
        height: widget.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: Stack(
          children: [
            if (hasImages)
              CarouselSlider.builder(
                itemCount: imageCount,
                itemBuilder: (context, index, realIndex) {
                  final fileModel = widget.imageFiles![index];
                  return GestureDetector(
                    onTap: widget.onImageTap == null
                        ? null
                        : () => widget.onImageTap?.call(fileModel),
                    child: DownloadImageWidget(
                      file: fileModel,
                      alignment: Alignment.topCenter,
                      isAntiAlias: true,
                      autoStart: widget.autoStart,
                      defaultAspectRatio: widget.defaultAspectRatio,
                      showActionButton: widget.showActionButton,
                      width: double.infinity,
                      emptyBuilder: (context) => Container(
                        width: double.infinity,
                        height: widget.height ?? double.infinity,
                        alignment: Alignment.center,
                        child: const MediaProgressIndicator(
                          indeterminate: true,
                        ),
                      ),
                    ),
                  );
                },
                options: CarouselOptions(
                  height: widget.height,
                  viewportFraction: 1.0,
                  enlargeCenterPage: false,
                  autoPlay: widget.autoPlay,
                  autoPlayInterval: widget.autoPlayInterval,
                  autoPlayAnimationDuration: const Duration(milliseconds: 400),
                  autoPlayCurve: Curves.easeInOut,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                ),
              )
            else
              // Placeholder when no images
              Container(
                width: double.infinity,
                height: widget.height ?? 150,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            // Dot indicators
            if (hasImages && showIndicator)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    imageCount,
                    (index) => Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentIndex == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
