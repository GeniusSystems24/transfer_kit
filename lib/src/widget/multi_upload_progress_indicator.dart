import '../model/multi_upload_file_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A widget that displays progress information for multiple file uploads.
///
/// Usage example:
/// ```dart
/// MultiUploadProgressIndicator(
///   progress: multiUploadTask, // MultiUploadTask from FileManagementSystem
///   showDetailedInfo: true,
///   width: 300,
///   height: 150,
///   showTitle: true,
///   onCancel: () {
///     // Handle cancel action
///     fileManagementSystem.cancelAllActiveTasks();
///   },
/// )
/// ```
///
/// This widget can be used as an overlay or within a dialog to show upload progress
/// for multiple files being uploaded simultaneously, with options to display detailed
/// information and a cancel button.
class MultiUploadProgressIndicator extends StatelessWidget {
  final MultiUploadFileTask progress;
  final bool showDetailedInfo;
  final Function()? onCancel;
  final double? width;
  final double? height;
  final bool showTitle;

  const MultiUploadProgressIndicator({
    super.key,
    required this.progress,
    this.showDetailedInfo = false,
    this.onCancel,
    this.width,
    this.height,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final completedFiles = _getCompletedCount();
    final totalFiles = progress.tasks.length;
    final isComplete = progress.isComplete;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showTitle) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Uploading files',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  if (onCancel != null && !isComplete)
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 18),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: isComplete
                      ? Container(
                          decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.check,
                              color: Colors.green, size: 18),
                        )
                      : CircularProgressIndicator(
                          value: progress.overallProgressPercentage / 100,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: .3),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          strokeWidth: 3,
                        )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(duration: const Duration(seconds: 1)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isComplete
                          ? 'Upload complete'
                          : '${progress.overallProgressPercentage.toStringAsFixed(0)}% complete',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Files: $completedFiles/$totalFiles',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(progress.totalBytesUploaded / (1024 * 1024)).toStringAsFixed(1)}/${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (showDetailedInfo) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                      begin: 0, end: progress.overallProgressPercentage / 100),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) {
                    return Stack(
                      children: [
                        LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              isComplete ? Colors.green : Colors.white),
                        ),
                        if (!isComplete)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SizedBox(
                                          height: 6,
                                          width: constraints.maxWidth)
                                      .animate(
                                          onPlay: (controller) =>
                                              controller.repeat())
                                      .shimmer(
                                          duration: const Duration(seconds: 1),
                                          color: Colors.white30);
                                },
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (!isComplete && progress.tasks.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _getEstimatedTimeRemaining(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.white60),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 250));
  }

  int _getCompletedCount() {
    return progress.tasks.where((status) => status.isComplete).length;
  }

  String _getEstimatedTimeRemaining() {
    // This is a placeholder - implement actual calculation
    if (progress.overallProgressPercentage < 5) {
      return 'Calculating time remaining...';
    } else if (progress.overallProgressPercentage > 95) {
      return 'Almost done...';
    } else {
      final remainingPercent = 100 - progress.overallProgressPercentage;
      // Very rough estimate
      final minutes = (remainingPercent / 20).ceil();
      return 'About ${minutes == 1 ? '1 minute' : '$minutes minutes'} remaining';
    }
  }
}
