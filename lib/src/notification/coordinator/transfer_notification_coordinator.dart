import 'dart:async';

import '../../model/file_task.dart';
import '../adapter/transfer_notification_adapter.dart';
import '../config/transfer_notification_config.dart';
import '../config/transfer_notification_template.dart';
import '../model/notification_event_kind.dart';
import '../model/notification_grouping_mode.dart';
import '../model/transfer_notification_payload.dart';
import '../model/transfer_type.dart';
import '../policy/transfer_notification_policy.dart';

/// Notification ID range used for generated tray IDs (R-004). Mirrors the
/// historical `BackgroundTransferService` range so users that upgrade
/// in-place do not see duplicate tray entries.
const int kNotificationIdRangeStart = 10000;
const int kNotificationIdRangeSize = 29999;

/// Computes a stable per-key notification ID inside the configured range.
int notificationIdFor(String key) =>
    kNotificationIdRangeStart + (key.hashCode.abs() % kNotificationIdRangeSize);

/// Wires `FileTaskRepository` events into a [TransferNotificationAdapter].
///
/// Owns the per-task subscription map, the per-task throttle gate, the
/// optional batch aggregator, and the policy filter. Adapter calls are
/// wrapped in `try/catch` so a failing notification never blocks a transfer
/// (FR-014).
class TransferNotificationCoordinator {
  /// Active configuration. The coordinator does not subscribe to changes —
  /// callers that swap configs must restart the coordinator.
  TransferNotificationConfig config;

  /// The adapter that renders notifications.
  final TransferNotificationAdapter adapter;

  /// Source of task lifecycle events. Each emission is a snapshot of the
  /// current task set; the coordinator computes per-task transitions.
  final Stream<Set<FileTask>> taskStream;

  late final TransferNotificationPolicy _policy;

  /// Optional logger callback so tests can inspect debug-level events.
  /// Defaults to a no-op so production stays silent (FR-014 / G-2).
  final void Function(String message, [Object? error])? onDebug;

  StreamSubscription<Set<FileTask>>? _repoSub;
  bool _started = false;
  bool _disposed = false;

  final Map<String, _TaskSubscription> _subscriptions = {};
  final Map<String, _GroupAggregator> _groups = {};

  TransferNotificationCoordinator({
    required this.config,
    required this.adapter,
    required this.taskStream,
    this.onDebug,
  }) {
    _policy = TransferNotificationPolicy(config);
  }

  /// Begins observing the task stream. Idempotent.
  void start() {
    if (_started || _disposed) return;
    _started = true;
    _repoSub = taskStream.listen(_onRepoSnapshot);
  }

  /// Cancels every per-task subscription, releases any pending throttle
  /// timers, and asks the adapter to dispose. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _repoSub?.cancel();
    for (final s in _subscriptions.values) {
      s.cancelTrailingTimer();
    }
    _subscriptions.clear();
    _groups.clear();
    try {
      await adapter.dispose();
    } catch (e) {
      onDebug?.call('adapter.dispose threw', e);
    }
  }

  void _onRepoSnapshot(Set<FileTask> tasks) {
    if (_disposed) return;
    final seenIds = <String>{};
    for (final task in tasks) {
      seenIds.add(task.id);
      _processTask(task);
    }
    // Tasks dropped from the repository should release their subscriptions.
    final stale = _subscriptions.keys
        .where((id) => !seenIds.contains(id))
        .toList(growable: false);
    for (final id in stale) {
      _retireSubscription(id);
    }
  }

  void _processTask(FileTask task) {
    final sub = _subscriptions.putIfAbsent(
      task.id,
      () => _TaskSubscription(notificationId: notificationIdFor(task.id)),
    );

    final newState = task.state;
    final transferType = task.type == FileTaskType.upload
        ? TransferType.upload
        : TransferType.download;

    if (sub.previousState == newState && _isTerminal(newState)) {
      // Already handled, nothing to do.
      return;
    }

    final eventKind = _eventKindFor(newState);

    // Build a "raw" payload with the resolved template fields.
    final payload = _buildPayload(
      task: task,
      sub: sub,
      transferType: transferType,
      eventKind: eventKind,
    );

    sub.previousState = newState;
    sub.lastPayload = payload;

    // Branch on grouping mode (R-009).
    final mode = config.grouping;
    if (mode == NotificationGroupingMode.none) {
      // Per FR-006 / R-009: suppress all dispatches.
      if (_isTerminal(newState)) _retireSubscription(task.id);
      return;
    }

    final groupId = task.groupId;
    if (mode == NotificationGroupingMode.batch &&
        groupId != null &&
        groupId.isNotEmpty) {
      _processGroup(groupId, payload);
      if (_isTerminal(newState)) _retireSubscription(task.id);
      return;
    }

    // perFile path.
    if (!_policy.shouldNotify(
      transferType: transferType,
      state: newState,
      kind: eventKind,
    )) {
      if (_isTerminal(newState)) _retireSubscription(task.id);
      return;
    }

    if (_isTerminal(newState)) {
      sub.cancelTrailingTimer();
      _dispatchTerminal(payload);
      _retireSubscription(task.id);
    } else if (eventKind == NotificationEventKind.progress) {
      _dispatchProgressThrottled(sub, payload);
    } else {
      // retry kind, route as showOrUpdateProgress with retry text.
      _safeAdapterCall(() => adapter.showOrUpdateProgress(payload));
    }
  }

  void _processGroup(String groupId, TransferNotificationPayload taskPayload) {
    final agg = _groups.putIfAbsent(
      groupId,
      () => _GroupAggregator(
        groupId: groupId,
        notificationId: notificationIdFor(groupId),
      ),
    );

    agg.update(taskPayload.taskId, taskPayload.progress);

    final groupedTitleBuilder =
        (taskPayload.transferType == TransferType.upload
                ? config.uploadTemplate
                : config.downloadTemplate)
            .groupedTitle;
    final title = groupedTitleBuilder != null
        ? groupedTitleBuilder(agg.total, agg.completed)
        : 'Transferring ${agg.completed}/${agg.total}';

    final groupPayload = taskPayload.copyWith(
      taskId: groupId,
      groupId: groupId,
      progress: agg.aggregateProgress,
      title: title,
      body: title,
      notificationId: agg.notificationId,
      eventKind: NotificationEventKind.progress,
      state: FileTaskState.running,
    );

    if (!_policy.shouldNotify(
      transferType: taskPayload.transferType,
      state: FileTaskState.running,
      kind: NotificationEventKind.progress,
    )) {
      return;
    }

    _safeAdapterCall(() => adapter.showOrUpdateProgress(groupPayload));
  }

  void _dispatchTerminal(TransferNotificationPayload payload) {
    switch (payload.state) {
      case FileTaskState.completed:
        _safeAdapterCall(() => adapter.showCompletion(payload));
        break;
      case FileTaskState.error:
        _safeAdapterCall(() => adapter.showError(payload));
        break;
      case FileTaskState.cancelled:
        _safeAdapterCall(() => adapter.showCompletion(payload));
        break;
      default:
        break;
    }
  }

  void _dispatchProgressThrottled(
    _TaskSubscription sub,
    TransferNotificationPayload payload,
  ) {
    final throttle = config.throttleDuration;
    final stopwatch = sub.throttle;

    if (!stopwatch.isRunning) {
      // First event — fire immediately and start the window.
      stopwatch.start();
      _safeAdapterCall(() => adapter.showOrUpdateProgress(payload));
      return;
    }

    final elapsed = stopwatch.elapsed;
    if (elapsed >= throttle) {
      stopwatch.reset();
      stopwatch.start();
      sub.cancelTrailingTimer();
      _safeAdapterCall(() => adapter.showOrUpdateProgress(payload));
      return;
    }

    // Within the throttle window — schedule trailing fire.
    sub.lastPayload = payload;
    sub.cancelTrailingTimer();
    final remaining = throttle - elapsed;
    sub.trailingTimer = Timer(remaining, () {
      final p = sub.lastPayload;
      if (p == null) return;
      sub.throttle.reset();
      sub.throttle.start();
      sub.trailingTimer = null;
      _safeAdapterCall(() => adapter.showOrUpdateProgress(p));
    });
  }

  TransferNotificationPayload _buildPayload({
    required FileTask task,
    required _TaskSubscription sub,
    required TransferType transferType,
    required NotificationEventKind eventKind,
  }) {
    final template = transferType == TransferType.upload
        ? config.uploadTemplate
        : config.downloadTemplate;

    final progress = task.progress.totalBytes > 0
        ? (task.progress.bytesTransferred / task.progress.totalBytes).clamp(
            0.0,
            1.0,
          )
        : (task.state == FileTaskState.completed ? 1.0 : 0.0);

    // Build a preliminary payload so the resolver can read fileName etc.
    final base = TransferNotificationPayload(
      taskId: task.id,
      groupId: (task.groupId == null || task.groupId!.isEmpty)
          ? null
          : task.groupId,
      transferType: transferType,
      state: task.state,
      eventKind: eventKind,
      progress: progress.toDouble(),
      bytesTransferred: task.progress.bytesTransferred,
      totalBytes: task.progress.totalBytes,
      fileName: task.fileName,
      title: '',
      body: '',
      notificationId: sub.notificationId,
      timestamp: DateTime.now(),
      actions: template.actions ?? const [],
    );

    final title = template.resolve(
      TransferNotificationTemplateKeys.title,
      base,
    );
    final body = _resolveBodyFor(template, base);

    return base.copyWith(title: title, body: body);
  }

  String _resolveBodyFor(
    TransferNotificationTemplate template,
    TransferNotificationPayload base,
  ) {
    switch (base.state) {
      case FileTaskState.running:
        return template.resolve(
          TransferNotificationTemplateKeys.progress,
          base,
        );
      case FileTaskState.paused:
        return template.resolve(TransferNotificationTemplateKeys.paused, base);
      case FileTaskState.completed:
        return template.resolve(TransferNotificationTemplateKeys.success, base);
      case FileTaskState.error:
        return template.resolve(TransferNotificationTemplateKeys.failure, base);
      case FileTaskState.cancelled:
        return template.resolve(
          TransferNotificationTemplateKeys.cancelled,
          base,
        );
      case FileTaskState.cached:
      case FileTaskState.waiting:
        return template.resolve(TransferNotificationTemplateKeys.body, base);
    }
  }

  NotificationEventKind _eventKindFor(FileTaskState state) {
    switch (state) {
      case FileTaskState.completed:
      case FileTaskState.error:
      case FileTaskState.cancelled:
      case FileTaskState.cached:
        return NotificationEventKind.terminal;
      case FileTaskState.running:
      case FileTaskState.paused:
      case FileTaskState.waiting:
        return NotificationEventKind.progress;
    }
  }

  bool _isTerminal(FileTaskState state) {
    return state == FileTaskState.completed ||
        state == FileTaskState.error ||
        state == FileTaskState.cancelled ||
        state == FileTaskState.cached;
  }

  void _retireSubscription(String taskId) {
    final sub = _subscriptions.remove(taskId);
    sub?.cancelTrailingTimer();
  }

  Future<void> _safeAdapterCall(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      onDebug?.call('adapter call threw', e);
    }
  }
}

/// Per-task subscription state (throttle, last payload, ID).
class _TaskSubscription {
  final int notificationId;
  final Stopwatch throttle = Stopwatch();
  Timer? trailingTimer;
  FileTaskState? previousState;
  TransferNotificationPayload? lastPayload;

  _TaskSubscription({required this.notificationId});

  void cancelTrailingTimer() {
    trailingTimer?.cancel();
    trailingTimer = null;
  }
}

/// Tracks per-group aggregated progress for batch grouping mode.
class _GroupAggregator {
  final String groupId;
  final int notificationId;
  final Map<String, double> _progressByTask = {};

  _GroupAggregator({required this.groupId, required this.notificationId});

  void update(String taskId, double progress) {
    _progressByTask[taskId] = progress;
  }

  int get total => _progressByTask.length;

  int get completed => _progressByTask.values.where((p) => p >= 1.0).length;

  double get aggregateProgress {
    if (_progressByTask.isEmpty) return 0.0;
    final sum = _progressByTask.values.fold<double>(0, (a, b) => a + b);
    return sum / _progressByTask.length;
  }
}
