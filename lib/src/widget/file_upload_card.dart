// ignore_for_file: avoid_print

import '../core/utils/file_utils.dart';
import '../model/file_path_and_url.dart';
import '../repository/file_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

import '../transfer_kit.dart';
import '../model/file_task.dart';

/// A card widget that displays file upload progress
///
/// Example:
/// ```dart
/// FileUploadCard(
///   filePath: 'path/to/local/file.jpg',
///   destinationPath: 'uploads/file.jpg', // Firebase Storage path
///   height: 200,
///   useStream: true, // Use stream to show real-time progress
///   onUploaded: (task) {
///     return Text('Upload complete! URL: ${task.downloadUrl}');
///   },
///   uploadingWidget: (context, task) => CustomUploadIndicator(task),
///   onError: (error) => Text('Error: $error'),
/// )
/// ```
///
/// This widget can be used in several ways:
///
/// **Basic image upload with preview:**
/// ```dart
/// FileUploadCard(
///   filePath: imageFile.path,
///   destinationPath: 'images/${DateTime.now().millisecondsSinceEpoch}.jpg',
///   onUploaded: (task) => Image.network(
///     task.downloadUrl!,
///     fit: BoxFit.cover,
///     loadingBuilder: (context, child, loadingProgress) =>
///       loadingProgress == null ? child : CircularProgressIndicator(),
///   ),
/// )
/// ```
///
/// **Document upload with task controls:**
/// ```dart
/// FileUploadCard(
///   filePath: pdfFile.path,
///   destinationPath: 'documents/report.pdf',
///   useTaskControl: true,
///   autoStart: false,
///   onUploaded: (task) => TextButton(
///     child: Text('Open PDF'),
///     onPressed: () => launchUrl(task.downloadUrl!),
///   ),
/// )
/// ```
///
/// **With custom upload progress UI:**
/// ```dart
/// FileUploadCard(
///   filePath: videoFile.path,
///   destinationPath: 'videos/movie.mp4',
///   useStream: true,
///   uploadingWidget: (context, task) => CustomUploadProgressUI(task),
///   constraints: BoxConstraints(maxHeight: 250),
/// )
/// ```
class FileUploadCard extends StatefulWidget {
  final String filePath;
  final String destinationPath;
  final String? storagePath; // Optional storage path for Firebase
  final Widget Function(FileTask task)? onUploaded;
  final Widget Function(String error)? onError;
  final double? height;
  final bool useStream;
  final bool useTaskControl;
  final bool autoStart;

  /// Widget to display while uploading or initializing
  ///
  /// Example:
  /// ```dart
  /// FileUploadCard(
  ///   uploadingWidget: (context, task) => Center(
  ///     child: Column(
  ///       mainAxisAlignment: MainAxisAlignment.center,
  ///       children: [
  ///         CircularProgressIndicator(
  ///           value: task?.progressPercentage != null ? task!.progressPercentage / 100 : null,
  ///         ),
  ///         const SizedBox(height: 16),
  ///         Text(
  ///           task != null
  ///               ? '${task.progressPercentage.toStringAsFixed(1)}%'
  ///               : 'Preparing upload...',
  ///           style: Theme.of(context).textTheme.bodyLarge,
  ///         ),
  ///         if (task != null)
  ///           Text(
  ///             '${task.uploadedSizeMB.toStringAsFixed(1)} MB / ${task.totalSizeMB.toStringAsFixed(1)} MB',
  ///             style: Theme.of(context).textTheme.bodySmall,
  ///           ),
  ///       ],
  ///     ),
  ///   ),
  /// )
  /// ```
  final Widget? Function(BuildContext context, FileTask? task)? uploadingWidget;

  /// Widget to display task controls
  final Widget Function(BuildContext context, FileTask task)? taskControlWidget;

  /// Custom controller to use instead of creating a new one
  /// If not provided, a new one will be created
  final TransferKit? controller;

  /// Whether to automatically initialize the controller in initState
  /// Set to false if you need custom initialization timing
  final bool autoInitializeController;

  /// Callback when task is completed
  final Function(FileTask task)? onTaskCompleted;

  /// Callback when task is removed
  final Function(FileTask task)? onTaskRemoved;

  final BoxConstraints? constraints;
  const FileUploadCard({
    super.key,
    required this.filePath,
    required this.destinationPath,
    this.storagePath, // Optional parameter for Firebase Storage path
    this.onUploaded,
    this.onError,
    this.height,
    this.useStream = false,
    this.uploadingWidget,
    this.constraints,
    this.useTaskControl = false,
    this.autoStart = false,
    this.taskControlWidget,
    this.controller,
    this.autoInitializeController = true,
    this.onTaskCompleted,
    this.onTaskRemoved,
  });

  @override
  State<FileUploadCard> createState() => _FileUploadCardState();
}

class _FileUploadCardState extends State<FileUploadCard>
    with SingleTickerProviderStateMixin {
  FileTask? _uploadTask;
  late final TransferKit _controller;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // Use provided controller or create a new one
    _controller = widget.controller ?? TransferKit.instance;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    if (widget.useTaskControl && widget.autoInitializeController) {
      _initializeTask();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeTask() async {
    try {
      final task = await _controller.uploadTask(
        filePathAndUrl: FilePathAndURL.local(
          path: widget.filePath,
          destinationPath: widget.storagePath ?? widget.destinationPath,
        ),
        autoStart: widget.autoStart,
        taskId: 'upload_${DateTime.now().millisecondsSinceEpoch}',
        group: FileGroupInfo(
          id: 'upload_${DateTime.now().millisecondsSinceEpoch}',
        ),
      );

      setState(() {
        _uploadTask = task;
      });

      _animationController.forward();
    } catch (e) {
      print('Failed to initialize upload task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface,
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        constraints: widget.constraints,
        child: widget.useTaskControl
            ? _buildTaskControlledUpload(context)
            : (widget.useStream
                  ? _StreamUploadContent(
                      filePath: widget.filePath,
                      destinationPath: widget.destinationPath,
                      storagePath: widget.storagePath,
                      onUploaded: widget.onUploaded,
                      onError: widget.onError,
                      uploadingWidget: widget.uploadingWidget,
                      controller: _controller,
                    )
                  : _FutureUploadContent(
                      filePath: widget.filePath,
                      destinationPath: widget.destinationPath,
                      storagePath: widget.storagePath,
                      onUploaded: widget.onUploaded,
                      onError: widget.onError,
                      controller: _controller,
                      uploadingWidget: widget.uploadingWidget,
                    )),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildTaskControlledUpload(BuildContext context) {
    return StreamBuilder<Set<FileTask>>(
      initialData: FileTaskRepository.instance.value,
      stream: FileTaskRepository.instance.stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.onError?.call(snapshot.error.toString()) ??
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 48,
                    ).animate().scale(
                      duration: 400.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
        }

        if (_uploadTask == null) {
          return Center(
            child:
                widget.uploadingWidget?.call(context, null) ??
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 1200.ms,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.4),
                        )
                        .animate()
                        .scale(
                          duration: 700.ms,
                          curve: Curves.easeOutBack,
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.0, 1.0),
                        ),
                    const SizedBox(height: 16),
                    Text(
                          'Preparing to upload...',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                        )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(begin: 0.2, end: 0),
                  ],
                ),
          );
        }

        final tasks = snapshot.data ?? {};
        final task = tasks.firstWhere(
          (t) => t.id == _uploadTask?.id,
          orElse: () => _uploadTask!,
        );

        // Custom task control widget if provided
        if (widget.taskControlWidget != null) {
          return widget.taskControlWidget!(context, task);
        }

        // Default task control UI
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _getStatusColor(task).withValues(alpha: 0.05),
                Theme.of(context).colorScheme.surface,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // File info row
              Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(task).withValues(alpha: 0.8),
                              _getStatusColor(task).withValues(alpha: 0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.file_upload_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.filePath.split('/').last,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.folder_outlined,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    widget.storagePath ??
                                        widget.destinationPath,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(context, task),
                    ],
                  )
                  .animate(controller: _animationController)
                  .fade(duration: 400.ms),

              const SizedBox(height: 16),

              // Progress bar with animation
              TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: task.progressPercentage / 100,
                    ),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Progress percentage and size
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${task.progressPercentage.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _getStatusColor(task),
                                ),
                              ),
                              Text(
                                '${FileUtils.formatSize(task.bytesTransferred)} / ${FileUtils.formatSize(task.totalBytes)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Progress bar
                          Stack(
                            children: [
                              // Background
                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              // Progress bar
                              FractionallySizedBox(
                                widthFactor: value,
                                child: Container(
                                  height: 10,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        _getStatusColor(task),
                                        _getStatusColor(
                                          task,
                                        ).withValues(alpha: 0.7),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              // Pulse effect for running tasks
                              if (task.isRunning)
                                FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        height: 10,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withValues(alpha: 0),
                                              Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
                                              Colors.white.withValues(alpha: 0),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                      ),
                                    )
                                    .animate(
                                      onPlay: (controller) =>
                                          controller.repeat(),
                                    )
                                    .shimmer(duration: 1500.ms, angle: 0),
                            ],
                          ),
                        ],
                      );
                    },
                  )
                  .animate(controller: _animationController)
                  .fade(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // Control buttons row
              Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        if (task.isWaiting)
                          _buildControlButton(
                            context: context,
                            icon: Icons.play_arrow_rounded,
                            label: 'Start',
                            onPressed: () async {
                              await _controller.startTask(task.id);
                            },
                            color: Colors.green,
                          ),
                        if (task.isRunning)
                          _buildControlButton(
                            context: context,
                            icon: Icons.pause_rounded,
                            label: 'Pause',
                            onPressed: () async {
                              await _controller.pauseTask(task.id);
                            },
                            color: Colors.amber,
                          ),
                        if (task.isPaused)
                          _buildControlButton(
                            context: context,
                            icon: Icons.play_arrow_rounded,
                            label: 'Resume',
                            onPressed: () async {
                              await _controller.resumeTask(task.id);
                            },
                            color: Colors.green,
                          ),
                        if (task.isError)
                          _buildControlButton(
                            context: context,
                            icon: Icons.refresh_rounded,
                            label: 'Retry',
                            onPressed: () async {
                              await _controller.retryTask(task.id);
                            },
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        if (!task.isComplete && !task.isCancelled)
                          _buildControlButton(
                            context: context,
                            icon: Icons.cancel_rounded,
                            label: 'Cancel',
                            onPressed: () async {
                              await _controller.cancelTask(task.id);
                            },
                            color: Colors.red,
                            isOutlined: true,
                          ),
                      ],
                    ),
                  )
                  .animate(controller: _animationController)
                  .fade(delay: 400.ms, duration: 400.ms),

              // Display completed URL
              if (task.isComplete &&
                  task.downloadUrl != null &&
                  widget.onUploaded != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.withValues(alpha: 0.15),
                          Colors.green.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: widget.onUploaded!(task)
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms),
                  ),
                ),

              // Error message
              if (task.isError && task.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.15),
                          Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 18,
                            )
                            .animate(
                              onPlay: (controller) => controller.repeat(
                                reverse: true,
                                period: const Duration(seconds: 4),
                              ),
                            )
                            .fadeIn(duration: 300.ms)
                            .then()
                            .fadeOut(delay: 2000.ms, duration: 700.ms),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(BuildContext context, FileTask task) {
    String label;
    Color color;

    if (task.isComplete) {
      label = 'Completed';
      color = Colors.green;
    } else if (task.isRunning) {
      label = 'Running';
      color = Colors.blue;
    } else if (task.isPaused) {
      label = 'Paused';
      color = Colors.amber;
    } else if (task.isWaiting) {
      label = 'Waiting';
      color = Colors.grey;
    } else if (task.isCancelled) {
      label = 'Cancelled';
      color = Colors.grey;
    } else if (task.isError) {
      label = 'Error';
      color = Colors.red;
    } else {
      label = 'Unknown';
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(task), color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(FileTask task) {
    if (task.isComplete) return Icons.check_circle;
    if (task.isRunning) return Icons.upload;
    if (task.isPaused) return Icons.pause_circle;
    if (task.isWaiting) return Icons.schedule;
    if (task.isCancelled) return Icons.cancel;
    if (task.isError) return Icons.error;
    return Icons.help_outline;
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    bool isOutlined = false,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 150),
      child:
          ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 16),
                label: Text(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutlined ? Colors.transparent : color,
                  foregroundColor: isOutlined ? color : Colors.white,
                  elevation: isOutlined ? 0 : 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isOutlined
                        ? BorderSide(color: color)
                        : BorderSide.none,
                  ),
                ),
              )
              .animate(
                onPlay: (controller) => controller.repeat(
                  reverse: true,
                  period: const Duration(seconds: 10),
                ),
              )
              .shimmer(
                delay: 3000.ms,
                duration: 1800.ms,
                color: isOutlined
                    ? color.withValues(alpha: 0.3)
                    : Colors.white24,
              ),
    );
  }
}

/// Widget that handles file upload using Future (uploadFile)
class _FutureUploadContent extends StatelessWidget {
  final String filePath;
  final String destinationPath;
  final String? storagePath;
  final Widget Function(FileTask task)? onUploaded;
  final Widget Function(String error)? onError;
  final Widget? Function(BuildContext context, FileTask? task)? uploadingWidget;
  final TransferKit controller;

  const _FutureUploadContent({
    required this.filePath,
    required this.destinationPath,
    this.storagePath,
    this.onUploaded,
    this.onError,
    this.uploadingWidget,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FileTask>(
      future: controller
          .uploadTask(
            filePathAndUrl: FilePathAndURL.local(
              path: filePath,
              destinationPath: storagePath ?? destinationPath,
            ),
            taskId: 'upload_${DateTime.now().millisecondsSinceEpoch}',
            group: FileGroupInfo(
              id: 'upload_${DateTime.now().millisecondsSinceEpoch}',
            ),
          )
          .catchError((error) {
            // Handle App Check errors specifically
            if (error.toString().contains('Too many attempts')) {
              throw 'Authentication error. Please try again later.';
            }
            throw error;
          }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          // Show a more user-friendly error message for App Check issues
          if (error.contains('Too many attempts')) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Authentication Error',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again in a few minutes',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }
          return Center(child: onError?.call(error) ?? Text('Error: $error'));
        }

        if (!snapshot.hasData) {
          // Create a placeholder task for the loading state
          final loadingTask = FileTask(
            id: 'loading_upload_${DateTime.now().millisecondsSinceEpoch}',
            filePath: filePath,
            destinationPath: storagePath ?? destinationPath,
            group: FileGroupInfo(
              id: 'loading_upload_${DateTime.now().millisecondsSinceEpoch}',
            ),
            state: FileTaskState.waiting,
            type: FileTaskType.upload,
            createdAt: DateTime.now(),
          );

          return Center(
            child:
                uploadingWidget?.call(context, loadingTask) ??
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator()
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 1200.ms,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.4),
                        ),
                    const SizedBox(height: 12),
                    Text(
                      'Uploading file...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(duration: 600.ms),
                  ],
                ),
          );
        }

        if (snapshot.data!.isComplete &&
            snapshot.data!.downloadUrl != null &&
            onUploaded != null) {
          return onUploaded!.call(snapshot.data!);
        } else {
          return Center(
            child:
                uploadingWidget?.call(context, snapshot.data) ??
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: snapshot.data!.progressPercentage / 100,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${snapshot.data!.progressPercentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Text(
                      '${FileUtils.formatSize(snapshot.data!.bytesTransferred)} / ${FileUtils.formatSize(snapshot.data!.totalBytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
          );
        }
      },
    );
  }
}

/// Widget that handles file upload using Stream (streamUpload)
class _StreamUploadContent extends StatelessWidget {
  final String filePath;
  final String destinationPath;
  final String? storagePath;
  final Widget Function(FileTask task)? onUploaded;
  final Widget Function(String error)? onError;
  final Widget? Function(BuildContext context, FileTask? task)? uploadingWidget;
  final TransferKit controller;

  const _StreamUploadContent({
    required this.filePath,
    required this.destinationPath,
    this.storagePath,
    this.onUploaded,
    this.uploadingWidget,
    this.onError,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FileTask>(
      stream: controller
          .uploadTaskStream(
            filePathAndUrl: FilePathAndURL.local(
              path: filePath,
              destinationPath: storagePath ?? destinationPath,
            ),
            taskId: const Uuid().v4(),
          )
          .handleError((error) {
            // Handle App Check errors specifically
            if (error.toString().contains('Too many attempts')) {
              return Stream.error(
                'Authentication error. Please try again later.',
              );
            }
            return Stream.error(error);
          }),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          // Show a more user-friendly error message for App Check issues
          if (error.contains('Too many attempts')) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Authentication Error',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again in a few minutes',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
          }
          return onError?.call(error) ?? Text('Error: $error');
        }

        if (!snapshot.hasData) {
          // Create a placeholder task for the loading state
          final loadingTask = FileTask(
            id: 'loading_upload_${DateTime.now().millisecondsSinceEpoch}',
            filePath: filePath,
            destinationPath: storagePath ?? destinationPath,
            group: FileGroupInfo(
              id: 'loading_upload_${DateTime.now().millisecondsSinceEpoch}',
            ),
            state: FileTaskState.waiting,
            type: FileTaskType.upload,
            createdAt: DateTime.now(),
          );

          return Center(
            child:
                uploadingWidget?.call(context, loadingTask) ??
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator()
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 1200.ms,
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.4),
                        ),
                    const SizedBox(height: 12),
                    Text(
                      'Preparing upload...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(duration: 600.ms),
                  ],
                ),
          );
        }

        final task = snapshot.data!;

        if (!task.isComplete) {
          return uploadingWidget?.call(context, task) ??
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    value: task.progressPercentage / 100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${task.progressPercentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Text(
                    '${FileUtils.formatSize(task.bytesTransferred)} / ${FileUtils.formatSize(task.totalBytes)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
        }

        if (task.downloadUrl != null && onUploaded != null) {
          return onUploaded!.call(task);
        } else {
          return const Center(child: Text('Uploaded successfully'));
        }
      },
    );
  }
}

Color _getStatusColor(FileTask task) {
  if (task.isComplete) {
    return Colors.green;
  } else if (task.isRunning) {
    return Colors.blue;
  } else if (task.isPaused) {
    return Colors.amber;
  } else if (task.isWaiting) {
    return Colors.grey;
  } else if (task.isCancelled) {
    return Colors.grey;
  } else if (task.isError) {
    return Colors.red;
  } else {
    return Colors.grey;
  }
}
