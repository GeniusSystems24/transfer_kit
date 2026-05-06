import '../model/file_task.dart';
import '../model/file_task_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A widget that displays the upload progress of a file task.
///
/// Usage example:
/// ```dart
/// FileUploadProgressIndicator(
///   task: uploadTask, // FileTask instance from TransferKit
///   showFileSize: true, // Show file size information
/// )
/// ```
///
/// This widget is typically used as an overlay on image or file previews
/// to indicate upload progress. It shows a circular progress indicator and
/// file size information.
class FileUploadProgressIndicator extends StatelessWidget {
  final FileTask task;
  final bool showFileSize;

  const FileUploadProgressIndicator({super.key, required this.task, this.showFileSize = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 25,
              height: 25,
              child: Center(
                child: CircularProgressIndicator(
                  value: task.progressPercentage / 100,
                  backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: .5),
                ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: const Duration(seconds: 1)),
              ),
            ),
            if (showFileSize)
              Text(
                '${task.uploadedSizeMB.toStringAsFixed(1)} MB / ${task.totalSizeMB.toStringAsFixed(1)} MB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
