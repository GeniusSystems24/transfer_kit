import 'dart:async';

import '../repository/file_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/extension/file_path_extension.dart';
import '../core/utils/file_utils.dart';
import '../transfer_kit.dart';
import '../model/file_path_and_url.dart';
import '../model/file_task.dart';
import '../model/file_task_extensions.dart';

/// A card widget that displays file loading progress with enhanced UI
///
/// Example:
/// ```dart
/// FileLoadingCard(
///   url: 'https://firebasestorage.googleapis.com/path/to/file.jpg',
///   onLoaded: (task) => Image.file(File(task.filePath)),
///   useStream: true, // Use stream to show real-time progress
///   checkCacheFirst: true, // Check cache before downloading
///   downloadingWidget: (context, progress) => CustomProgressIndicator(progress),
///   onError: (error) => Text('Error: $error'),
/// )
/// ```
///
/// This widget can be used in several different ways:
///
/// **Basic usage with cached image:**
/// ```dart
/// FileLoadingCard(
///   url: imageUrl,
///   onLoaded: (task) => Image.file(File(task.filePath), fit: BoxFit.cover),
/// )
/// ```
///
/// **With task controls for manual management:**
/// ```dart
/// FileLoadingCard(
///   url: documentUrl,
///   onLoaded: (task) => PDFView(filePath: task.filePath),
///   useTaskControl: true,
///   autoStart: false,
/// )
/// ```
///
/// **With custom progress UI:**
/// ```dart
/// FileLoadingCard(
///   url: videoUrl,
///   onLoaded: (task) => VideoPlayer(File(task.filePath)),
///   downloadingWidget: (context, progress) => CustomProgressIndicator(progress),
///   constraints: BoxConstraints(maxHeight: 300),
/// )
/// ```
///
/// **With initial task value for resuming downloads:**
/// ```dart
/// // Store task when app is closing
/// final task = await fileManager.getTaskById('download_123');
/// await prefs.setString('saved_task', jsonEncode(task.toJson()));
///
/// // Later, when restoring the app state:
/// final savedTaskJson = prefs.getString('saved_task');
/// if (savedTaskJson != null) {
///   final restoredTask = FileTask.fromJson(jsonDecode(savedTaskJson));
///
///   FileLoadingCard(
///     url: restoredTask.downloadUrl!,
///     onLoaded: (task) => Image.file(File(task.filePath)),
///     initialTaskValue: restoredTask, // Restore the previous download state
///     useTaskControl: true,
///   )
/// }
/// ```
class FileLoadingCard extends StatefulWidget {
  final String url;
  final Widget Function(FileTask task) onLoaded;
  final Widget Function(String error)? onError;
  final bool useStream;
  final bool checkCacheFirst;
  final bool useTaskControl;
  final bool autoStart;

  /// Widget to display while downloading or loading
  ///
  /// Example:
  /// ```dart
  /// FileLoadingCard(
  ///   downloadingWidget: (context, progress) => Center(
  ///     child: Column(
  ///       mainAxisAlignment: MainAxisAlignment.center,
  ///       children: [
  ///         CircularProgressIndicator(
  ///           value: progress.progressPercentage / 100,
  ///         ),
  ///         const SizedBox(height: 16),
  ///         Text(
  ///           '${progress.progressPercentage.toStringAsFixed(1)}%',
  ///           style: Theme.of(context).textTheme.bodyLarge,
  ///         ),
  ///         Text(
  ///           '${progress.downloadedSizeMB.toStringAsFixed(1)} MB / ${progress.totalSizeMB.toStringAsFixed(1)} MB',
  ///           style: Theme.of(context).textTheme.bodySmall,
  ///         ),
  ///       ],
  ///     ),
  ///   ),
  /// )
  /// ```
  final Widget? Function(BuildContext context, FileTask? progress)?
  downloadingWidget;

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

  /// Initial task value to pre-set before initialization
  /// If provided, this task will be used instead of creating a new one
  /// Useful for restoring task state from previous sessions or for testing
  final FileTask? initialTaskValue;

  final BoxConstraints? constraints;
  final String? tag;
  const FileLoadingCard({
    super.key,
    required this.url,
    required this.onLoaded,
    this.onError,
    this.useStream = false,
    this.checkCacheFirst = true,
    this.downloadingWidget,
    this.constraints,
    this.tag,
    this.useTaskControl = false,
    this.autoStart = false,
    this.taskControlWidget,
    this.controller,
    this.autoInitializeController = true,
    this.onTaskCompleted,
    this.onTaskRemoved,
    this.initialTaskValue,
  });

  @override
  State<FileLoadingCard> createState() => _FileLoadingCardState();
}

class _FileLoadingCardState extends State<FileLoadingCard>
    with SingleTickerProviderStateMixin {
  FileTask? _downloadTask;
  late final TransferKit _controller;
  bool _isInitialized = false;
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

    // Set initial task value if provided
    if (widget.initialTaskValue != null) {
      setState(() {
        _downloadTask = widget.initialTaskValue;
        _isInitialized = true;
      });
      _animationController.forward();
    } else if (widget.useTaskControl && widget.autoInitializeController) {
      _initializeTask();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeTask() async {
    if (_isInitialized) return;

    try {
      final task = await _controller.downloadTask(
        filePathAndUrl: FilePathAndURL.url(url: widget.url),
        autoStart: widget.autoStart,
        taskId: 'download_${widget.url.toHashName()}',
      );

      setState(() {
        _downloadTask = task;
        _isInitialized = true;
      });

      _animationController.forward();
    } catch (e) {
      debugPrint('Failed to initialize download task: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_downloadTask != null && _downloadTask!.isComplete) {
      widget.onTaskCompleted?.call(_downloadTask!);
      return widget.onLoaded(_downloadTask!);
    }
    return Container(
      constraints: widget.constraints,
      child: widget.useTaskControl
          ? _buildTaskControlledDownload(context)
          : (widget.useStream
                ? _StreamLoadingContent(
                    url: widget.url,
                    onLoaded: widget.onLoaded,
                    onError: widget.onError,
                    checkCacheFirst: widget.checkCacheFirst,
                    downloadingWidget: widget.downloadingWidget,
                    controller: _controller,
                    initialTaskValue: widget.initialTaskValue,
                  )
                : _FutureLoadingContent(
                    url: widget.url,
                    onLoaded: widget.onLoaded,
                    onError: widget.onError,
                    checkCacheFirst: widget.checkCacheFirst,
                    controller: _controller,
                    initialTaskValue: widget.initialTaskValue,
                    downloadingWidget: widget.downloadingWidget,
                  )),
    );
  }

  Widget _buildTaskControlledDownload(BuildContext context) {
    // If we have an initialTaskValue and it's not in the stream yet,
    // we can display it directly before the stream is established
    if (widget.initialTaskValue != null && !_isInitialized) {
      final task = widget.initialTaskValue!;
      return _buildTaskContent(context, task);
    }

    return StreamBuilder<Set<FileTask>>(
      initialData: FileTaskRepository.instance.value,
      stream: FileTaskRepository.instance.stream,
      builder: (context, snapshot) {
        if (!_isInitialized) {
          return Center(
            child:
                widget.downloadingWidget?.call(context, null) ??
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
                          'Preparing to download...',
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

        if (snapshot.hasError) {
          return widget.onError?.call(snapshot.error.toString()) ??
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                            size: 42,
                          ),
                        )
                        .animate()
                        .scale(duration: 400.ms, curve: Curves.easeOutBack)
                        .shimmer(
                          delay: 400.ms,
                          duration: 1800.ms,
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withValues(alpha: 0.2),
                        ),
                    const SizedBox(height: 16),
                    Text(
                      'Error Occurred',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: () {
                            if (_downloadTask != null) {
                              _controller.retryTask(_downloadTask!.id);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Try Again',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ).animate().scale(
                      delay: 200.ms,
                      duration: 300.ms,
                      curve: Curves.easeOut,
                    ),
                  ],
                ),
              );
        }

        final tasks = snapshot.data ?? {};
        final task = tasks.firstWhere(
          (t) => t.id == _downloadTask?.id,
          orElse: () => _downloadTask!,
        );

        return _buildTaskContent(context, task);
      },
    );
  }

  // Extract the task content building to a separate method for reuse
  Widget _buildTaskContent(BuildContext context, FileTask task) {
    // Custom task control widget if provided
    if (widget.taskControlWidget != null) {
      return widget.taskControlWidget!(context, task);
    }

    // Default task control UI
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getContainerColor(task),
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
                      Icons.file_download_rounded,
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
                          _getFileName(task),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getFormattedDate(task),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.7),
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
              .fade(duration: 400.ms)
              .slideY(begin: 0.2, end: 0),

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
                          RichText(
                            text: TextSpan(
                              style: DefaultTextStyle.of(context).style,
                              children: [
                                TextSpan(
                                  text:
                                      '${task.progressPercentage.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _getStatusColor(task),
                                  ),
                                ),
                                TextSpan(
                                  text: ' downloaded',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          // Progress bar
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: 10,
                            width: MediaQuery.of(context).size.width * value,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getStatusColor(task),
                                  _getStatusColor(task).withValues(alpha: 0.7),
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: _getStatusColor(
                                    task,
                                  ).withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          // Animated glow effect for running tasks
                          if (task.isRunning)
                            Positioned(
                                  left:
                                      MediaQuery.of(context).size.width *
                                          value -
                                      20,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 20,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getStatusColor(
                                            task,
                                          ).withValues(alpha: 0),
                                          _getStatusColor(
                                            task,
                                          ).withValues(alpha: 0.5),
                                          _getStatusColor(
                                            task,
                                          ).withValues(alpha: 0),
                                        ],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                )
                                .animate(
                                  onPlay: (controller) => controller.repeat(
                                    period: const Duration(seconds: 2),
                                  ),
                                )
                                .custom(
                                  duration: 2000.ms,
                                  builder: (context, value, child) =>
                                      Transform.translate(
                                        offset: Offset(20 * value, 0),
                                        child: child,
                                      ),
                                ),
                        ],
                      ),
                    ],
                  );
                },
              )
              .animate(controller: _animationController)
              .fade(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(height: 16),

          // Control buttons
          _buildControlButtons(task)
              .animate(controller: _animationController)
              .fade(delay: 400.ms, duration: 400.ms)
              .slideY(begin: 0.4, end: 0),

          // Display completed file
          if (task.isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget
                    .onLoaded(task)
                    .animate()
                    .fade(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.95, 0.95),
                      end: const Offset(1.0, 1.0),
                      duration: 400.ms,
                      curve: Curves.easeOut,
                    ),
              ),
            ),

          // Error message
          if (task.isError && task.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        task.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  Widget _buildControlButtons(FileTask task) {
    return Wrap(
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
    );
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
          Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: color.withValues(alpha: 0.1),
                  highlightColor: color.withValues(alpha: 0.05),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: isOutlined
                          ? null
                          : LinearGradient(
                              colors: [
                                color,
                                Color.lerp(color, Colors.white, 0.2) ?? color,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: isOutlined ? Colors.transparent : null,
                      borderRadius: BorderRadius.circular(12),
                      border: isOutlined
                          ? Border.all(
                              color: color.withValues(alpha: 0.8),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: isOutlined
                          ? null
                          : [
                              BoxShadow(
                                color: color.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: isOutlined ? color : Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: isOutlined ? color : Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
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

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.7), color.withValues(alpha: 0.4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.8), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(task), color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    // Apply shimmer animation only for running tasks
    if (task.isRunning) {
      return badge
          .animate(
            onPlay: (controller) => controller.repeat(
              reverse: true,
              period: const Duration(seconds: 2),
            ),
          )
          .shimmer(
            duration: 800.ms,
            color: Colors.white.withValues(alpha: 0.3),
          );
    }

    return badge;
  }

  IconData _getStatusIcon(FileTask task) {
    if (task.isComplete) return Icons.check_circle;
    if (task.isRunning) return Icons.downloading_rounded;
    if (task.isPaused) return Icons.pause_circle;
    if (task.isWaiting) return Icons.schedule;
    if (task.isCancelled) return Icons.cancel;
    if (task.isError) return Icons.error;
    return Icons.help_outline;
  }

  Color _getStatusColor(FileTask task) {
    if (task.isComplete) return Colors.green;
    if (task.isRunning) return Colors.blue;
    if (task.isPaused) return Colors.amber;
    if (task.isWaiting) return Colors.grey;
    if (task.isCancelled) return Colors.grey;
    if (task.isError) return Colors.red;
    return Theme.of(context).colorScheme.primary;
  }

  Color _getContainerColor(FileTask task) {
    if (task.isError) {
      return Theme.of(context).colorScheme.error.withValues(alpha: 0.05);
    } else if (task.isComplete) {
      return Colors.green.withValues(alpha: 0.05);
    }
    return Colors.transparent;
  }

  String _getFileName(FileTask task) {
    if (task.type == FileTaskType.download) {
      final urlParts = task.downloadUrl?.split('/');
      return urlParts?.last.split('?').first ?? '';
    } else {
      return task.destinationPath?.fileName ?? '';
    }
  }

  String _getFormattedDate(FileTask task) {
    // Simple date formatting
    final now = DateTime.now();
    final difference = now.difference(task.createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }
}

/// Widget that handles file loading using Future (getFile)
class _FutureLoadingContent extends StatelessWidget {
  final String url;
  final Widget Function(FileTask task) onLoaded;
  final Widget Function(String error)? onError;
  final bool checkCacheFirst;
  final TransferKit controller;
  final FileTask? initialTaskValue;
  final Widget? Function(BuildContext context, FileTask? progress)?
  downloadingWidget;

  const _FutureLoadingContent({
    required this.url,
    required this.onLoaded,
    this.onError,
    this.checkCacheFirst = true,
    required this.controller,
    this.initialTaskValue,
    this.downloadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    // If we have an initialTaskValue that's complete, show it immediately
    if (initialTaskValue != null && initialTaskValue!.isComplete) {
      return onLoaded(initialTaskValue!)
          .animate()
          .fade(duration: 300.ms)
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.0, 1.0),
            duration: 300.ms,
            curve: Curves.easeOut,
          );
    }

    return FutureBuilder<FileTask>(
      future: _loadFileTask(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return onError?.call(snapshot.error.toString()) ??
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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

        if (!snapshot.hasData) {
          // Create a placeholder task for the loading state
          final loadingTask = FileTask(
            id: 'loading_${url.toHashName()}',
            filePath: url.toHashName().toCachedPath(),
            downloadUrl: url,
            group: FileGroupInfo(id: 'loading_${url.toHashName()}'),
            state: FileTaskState.waiting,
            createdAt: DateTime.now(),
          );

          return Center(
            child:
                downloadingWidget?.call(context, loadingTask) ??
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
                      'Loading file...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(duration: 600.ms),
                  ],
                ),
          );
        }

        return onLoaded(snapshot.data!)
            .animate()
            .fade(duration: 300.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
              duration: 300.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }

  Future<FileTask> _loadFileTask() async {
    // If we have an initialTaskValue that's not complete, use it as a starting point
    if (initialTaskValue != null && !initialTaskValue!.isComplete) {
      // Continue the task from where it left off
      return await controller.downloadTask(
        filePathAndUrl: FilePathAndURL.url(url: url),
        taskId: initialTaskValue!.id,
        autoStart: true,
        group: FileGroupInfo(
          id: initialTaskValue!.groupId ?? 'download_${url.toHashName()}',
        ),
      );
    }

    if (checkCacheFirst) {
      // Check if file is cached
      final cachedPath = await controller.getCachedFilePath(url);
      if (cachedPath != null) {
        // Create a completed FileTask for the cached file
        return FileTask(
          id: 'cached_${url.toHashName()}',
          filePath: cachedPath,
          downloadUrl: url,
          group: FileGroupInfo(id: 'cached_${url.toHashName()}'),
          state: FileTaskState.cached,
          createdAt: DateTime.now(),
        );
      }
    }

    // Download the file if not cached
    return await controller.downloadTask(
      filePathAndUrl: FilePathAndURL.url(url: url),
      taskId: 'download_${url.toHashName()}',
      autoStart: true,
      group: FileGroupInfo(id: 'download_${url.toHashName()}'),
    );
  }
}

/// Widget that handles file loading using Stream (streamFile)
class _StreamLoadingContent extends StatelessWidget {
  final String url;
  final Widget Function(FileTask task) onLoaded;
  final Widget Function(String error)? onError;
  final bool checkCacheFirst;
  final TransferKit controller;
  final FileTask? initialTaskValue;
  final Widget? Function(BuildContext context, FileTask? progress)?
  downloadingWidget;

  const _StreamLoadingContent({
    required this.url,
    required this.onLoaded,
    this.onError,
    this.checkCacheFirst = true,
    this.downloadingWidget,
    required this.controller,
    this.initialTaskValue,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FileTask>(
      stream: _getStream(),
      initialData:
          initialTaskValue, // Use initialTaskValue as initialData if available
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return onError?.call(snapshot.error.toString()) ??
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
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

        if (!snapshot.hasData) {
          // Create a placeholder task for the loading state
          final loadingTask = FileTask(
            id: 'loading_${url.toHashName()}',
            filePath: url.toHashName().toCachedPath(),
            downloadUrl: url,
            group: FileGroupInfo(id: 'loading_${url.toHashName()}'),
            state: FileTaskState.waiting,
            createdAt: DateTime.now(),
          );

          return Center(
            child:
                downloadingWidget?.call(context, loadingTask) ??
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
                      'Loading file...',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(duration: 600.ms),
                  ],
                ),
          );
        }

        final progress = snapshot.data!;

        if (!progress.isComplete) {
          return downloadingWidget?.call(context, progress) ??
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: progress.progressPercentage / 100,
                      ),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, value, _) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Progress circle
                            SizedBox(
                              height: 120,
                              width: 120,
                              child: CircularProgressIndicator(
                                value: value,
                                strokeWidth: 8,
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            // Percentage text
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${progress.progressPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  progress.isRunning
                                      ? 'Downloading'
                                      : progress.isPaused
                                      ? 'Paused'
                                      : 'Waiting',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // File size
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.data_usage_rounded,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${progress.downloadedSizeMB.toStringAsFixed(1)} MB / ${progress.totalSizeMB.toStringAsFixed(1)} MB',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fade(duration: 300.ms).slideY(begin: 0.1, end: 0),
              );
        }

        return onLoaded(progress)
            .animate()
            .fade(duration: 300.ms)
            .scale(
              begin: const Offset(0.95, 0.95),
              end: const Offset(1.0, 1.0),
              duration: 300.ms,
              curve: Curves.easeOut,
            );
      },
    );
  }

  Stream<FileTask> _getStream() {
    // If we have an initialTaskValue, use its ID to continue the download
    final taskId = initialTaskValue?.id ?? 'download_${url.toHashName()}';

    return controller.downloadTaskStream(
      filePathAndUrl: FilePathAndURL.url(url: url),
      taskId: taskId,
    );
  }
}
