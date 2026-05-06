import '../model/file_task.dart';
import '../model/file_task_extensions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A widget that displays the download progress of a file task.
///
/// Usage example:
/// ```dart
/// FileDownloadProgressIndicator(
///   task: downloadTask, // FileTask instance from FileManagementSystem
///   showFileName: true, // Show the file name
///   showFileSize: true, // Show file size information
///   showDetailedInfo: true, // Show detailed progress information
/// )
/// ```
///
/// This widget is typically used inside other widgets like FileLoadingCard or
/// in custom download UI implementations.
class FileDownloadProgressIndicator extends StatelessWidget {
  final FileTask task;
  final bool showFileName;
  final bool showDetailedInfo;
  final bool showFileSize;
  final Function()? onCancel;
  final double? width;
  final double? height;

  const FileDownloadProgressIndicator({
    super.key,
    required this.task,
    this.showFileName = false,
    this.showDetailedInfo = false,
    this.showFileSize = true,
    this.onCancel,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Get icon and color based on file type
    final fileInfo = _getFileTypeInfo(task.fileName);
    final isComplete = task.isComplete;
    final isRunning = task.state == FileTaskState.running;
    final hasError = task.state == FileTaskState.error;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showFileName) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: fileInfo.color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Icon(fileInfo.icon, color: fileInfo.color, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      task.fileName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onCancel != null && !isComplete)
                    IconButton(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
                  width: 26,
                  height: 26,
                  child: Stack(
                    children: [
                      Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child:
                              isComplete
                                  ? Container(
                                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), shape: BoxShape.circle),
                                    child: const Icon(Icons.check, color: Colors.green, size: 18),
                                  )
                                  : CircularProgressIndicator(
                                        value: hasError ? 1.0 : task.progressPercentage / 100,
                                        backgroundColor: Theme.of(context).colorScheme.outline.withValues(alpha: .3),
                                        valueColor: AlwaysStoppedAnimation<Color>(hasError ? Colors.red : Colors.white),
                                        strokeWidth: 3,
                                      )
                                      .animate(onPlay: (controller) => controller.repeat())
                                      .shimmer(duration: const Duration(seconds: 1), delay: const Duration(milliseconds: 500)),
                        ),
                      ),
                      if (hasError) const Center(child: Icon(Icons.error, color: Colors.red, size: 18)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showFileSize)
                      Row(
                        children: [
                          Text(
                            '${task.downloadedSizeMB.toStringAsFixed(1)} MB',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            ' / ${task.totalSizeMB.toStringAsFixed(1)} MB',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    if (showDetailedInfo && !isComplete)
                      Text(
                        isRunning ? '${task.progressPercentage.toStringAsFixed(0)}% • 1.2 MB/s' : _getStatusText(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
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
                  tween: Tween<double>(begin: 0, end: task.progressPercentage / 100),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, _) {
                    return LinearProgressIndicator(
                      value: hasError ? 1.0 : value,
                      minHeight: 4,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isComplete
                            ? Colors.green
                            : hasError
                            ? Colors.red
                            : Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (task.state) {
      case FileTaskState.waiting:
        return 'Waiting to download...';
      case FileTaskState.running:
        return 'Downloading...';
      case FileTaskState.paused:
        return 'Download paused';
      case FileTaskState.completed:
        return 'Processing file...';
      case FileTaskState.error:
        return 'Download failed';
      default:
        return 'Unknown status';
    }
  }

  _FileTypeInfo _getFileTypeInfo(String fileName) {
    final fileExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].contains(fileExtension)) {
      return _FileTypeInfo(Icons.image, Colors.blue);
    } else if (fileExtension == 'pdf') {
      return _FileTypeInfo(Icons.picture_as_pdf, Colors.red);
    } else if (['doc', 'docx', 'odt', 'rtf', 'txt'].contains(fileExtension)) {
      return _FileTypeInfo(Icons.description, Colors.blue);
    } else if (['xls', 'xlsx', 'csv'].contains(fileExtension)) {
      return _FileTypeInfo(Icons.table_chart, Colors.green);
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'].contains(fileExtension)) {
      return _FileTypeInfo(Icons.video_file, Colors.purple);
    } else if (['mp3', 'wav', 'ogg', 'flac', 'm4a'].contains(fileExtension)) {
      return _FileTypeInfo(Icons.audio_file, Colors.amber);
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(fileExtension)) {
      return _FileTypeInfo(Icons.folder_zip, Colors.brown);
    } else {
      return _FileTypeInfo(Icons.file_download, Colors.grey);
    }
  }
}

class _FileTypeInfo {
  final IconData icon;
  final Color color;

  _FileTypeInfo(this.icon, this.color);
}
