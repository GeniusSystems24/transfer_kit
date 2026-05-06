import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

import '../transfer_kit.dart';
import '../model/file_path_and_url.dart';
import '../model/file_task.dart';
import '../repository/file_path_and_url_repository.dart';
import '../repository/file_task_repository.dart';

/// A widget that handles downloading a file and displays different UI states.
///
/// Usage example:
/// ```dart
/// DownloadFileWidget(
///   url: 'https://example.com/file.pdf',
///   taskId: 'download_123',
///   autoStart: true,
///   completedBuilder: (context, file) => Image.file(file),
///   loadingBuilder: (context, task) => CircularProgressIndicator(
///     value: task?.progressPercentage,
///   ),
///   errorBuilder: (context, task, error) => Text('Error: $error'),
/// )
/// ```
class DownloadFileWidget extends StatefulWidget {
  final String url;
  final String taskId;
  final FileGroupInfo? group;
  final bool autoStart;

  final Widget Function(BuildContext context, File file) completedBuilder;
  final Widget Function(BuildContext context, FileTask? fileTask) loadingBuilder;
  final Widget Function(BuildContext context, FileTask? fileTask, Object error)? errorBuilder;
  final Stream<FileTask> Function(String url, String taskId, FileGroupInfo? group, bool autoStart)? downloadTaskStream;

  const DownloadFileWidget({
    super.key,
    required this.url,
    required this.taskId,
    this.group,
    this.autoStart = false,
    required this.completedBuilder,
    required this.loadingBuilder,
    this.errorBuilder,
    this.downloadTaskStream,
  });

  @override
  State<DownloadFileWidget> createState() => _DownloadFileWidgetState();
}

class _DownloadFileWidgetState extends State<DownloadFileWidget> {
  FilePathAndURL? _cachedFilePathAndUrl;
  FileTask? _cachedFileTask;

  FilePathAndURL? get localFilePathAndUrl =>
      _cachedFilePathAndUrl ??= FilePathAndURLRepository.instance.getByUrl(widget.url);

  FileTask? get fileTask =>
      _cachedFileTask ??= FileTaskRepository.instance.getTaskByUrl(widget.url);

  @override
  void initState() {
    super.initState();
    _startDownloadIfNeeded();
  }

  void _startDownloadIfNeeded() {
    if (widget.autoStart && fileTask == null && localFilePathAndUrl == null) {
      widget.downloadTaskStream?.call(widget.url, widget.taskId, widget.group, widget.autoStart) ??
          FileManagementSystem.instance.downloadTaskStream(
            filePathAndUrl: FilePathAndURL.url(url: widget.url),
            taskId: widget.taskId,
            group: widget.group,
            autoStart: widget.autoStart,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if file is already downloaded locally
    if (localFilePathAndUrl != null) {
      Logger().d('File already exists locally: ${localFilePathAndUrl!.path}');
      return widget.completedBuilder(context, File(localFilePathAndUrl!.path));
    }

    // Check if task is already complete
    if (fileTask?.isComplete ?? false) {
      Logger().d('Download task already complete');
      return widget.completedBuilder(context, File(fileTask!.filePathAndURL.path));
    }

    return StreamBuilder<FileTask?>(
      initialData: fileTask,
      stream: FileTaskRepository.instance.streamFirstWhereOrNull((task) => task.url == widget.url),
      builder: (context, asyncSnapshot) {
        final currentTask = asyncSnapshot.data;

        if (asyncSnapshot.hasError && widget.errorBuilder != null) {
          return widget.errorBuilder!(context, currentTask, asyncSnapshot.error!);
        }

        if (currentTask?.isComplete ?? false) {
          _cachedFilePathAndUrl = currentTask!.filePathAndURL;
          _cachedFileTask = currentTask;
          return widget.completedBuilder(context, File(currentTask.filePathAndURL.path));
        }

        return widget.loadingBuilder(context, currentTask);
      },
    );
  }
}
