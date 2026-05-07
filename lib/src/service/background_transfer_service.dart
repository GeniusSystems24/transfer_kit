// ignore_for_file: avoid_print

import 'dart:async';

import 'package:workmanager/workmanager.dart';

import '../repository/background_task_repository.dart';
import 'task_management_service.dart';

/// Service responsible for handling background file transfers.
///
/// As of the notification-control-ui feature this service no longer renders
/// notifications directly — the notification surface lives in
/// `TransferNotificationCoordinator` (composed of `TransferNotificationConfig`
/// + `TransferNotificationAdapter`). This file only manages the
/// `Workmanager` scheduling and the in-memory active-batch set.
class BackgroundTransferService {
  // Singleton instance
  static final BackgroundTransferService instance =
      BackgroundTransferService._internal();
  factory BackgroundTransferService() => instance;
  BackgroundTransferService._internal();

  // Constants
  static const String taskName = 'fileTransferTask';
  static const String periodicTaskName = 'fileTransferPeriodicTask';
  static String route = '/task-inspector';

  /// Starts tracking a batch of file tasks for background processing.
  Future<void> startBackgroundTracking(String groupId) async {
    BackgroundTaskRepository.instance.add(groupId);
    await _scheduleBackgroundTask();
  }

  /// Schedule a one-off or periodic background task based on the situation.
  Future<void> _scheduleBackgroundTask() async {
    await Workmanager().registerOneOffTask(
      taskName,
      taskName,
      initialDelay: const Duration(seconds: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(minutes: 1),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Stop tracking a batch of file tasks.
  Future<void> stopBackgroundTracking(String groupId) async {
    BackgroundTaskRepository.instance.remove(groupId);

    if (BackgroundTaskRepository.instance.value.isEmpty) {
      await Workmanager().cancelByUniqueName(taskName);
      await Workmanager().cancelByUniqueName(periodicTaskName);
    }
  }

  /// Get active batch IDs.
  Future<Set<String>> getActiveBatchIds() async =>
      BackgroundTaskRepository.instance.value;

  static Future<void> onBackgroundExecute(
    Map<String, dynamic>? inputData,
  ) async {
    final BackgroundTransferService service = BackgroundTransferService();
    final TaskManagementService taskService = TaskManagementService.instance;

    try {
      final activeBatchIds = await service.getActiveBatchIds();

      for (final groupId in activeBatchIds) {
        final tasks = taskService.getTasksByGroupId(groupId);

        bool hasError = false;
        bool allCompleted = true;

        for (final task in tasks) {
          if (task.isError) hasError = true;
          if (!task.isComplete && !task.isCached) allCompleted = false;
        }

        if (hasError || allCompleted) {
          await service.stopBackgroundTracking(groupId);
        }
      }

      if (activeBatchIds.isNotEmpty) {
        await service._scheduleBackgroundTask();
      }
    } catch (e) {
      print('Error in background task: $e');
      rethrow;
    }
  }
}
