// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:awesome_notifications/awesome_notifications.dart';
import '../repository/background_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'task_management_service.dart';

/// Service responsible for handling background file transfers
class BackgroundTransferService {
  // Singleton instance
  static final BackgroundTransferService instance =
      BackgroundTransferService._internal();
  factory BackgroundTransferService() => instance;
  BackgroundTransferService._internal();
  // Constants
  static const String _lastProgressUpdateKey =
      'file_management_last_progress_update';
  static const String taskName = 'fileTransferTask';
  static const String periodicTaskName = 'fileTransferPeriodicTask';
  static String route = '/task-inspector';

  // Notification channel
  static const String notificationChannelKey = 'file_transfer_channel';
  static const String notificationChannelName = 'File Transfers';
  static const String notificationChannelDescription =
      'Notifications for file uploads and downloads';

  /// Notification channel
  static NotificationChannel channel() => NotificationChannel(
        channelKey: notificationChannelKey,
        channelName: notificationChannelName,
        channelDescription: notificationChannelDescription,
        defaultColor: const Color(0xFF9D50DD),
        ledColor: const Color(0xFF9D50DD),
        importance: NotificationImportance.High,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        locked: true, // Prevent user from dismissing
        onlyAlertOnce: false, // Allow multiple alerts for updates
      );

  // Notification IDs (use different ranges for different notification types)
  static const int _progressNotificationIdStart =
      10000; // IDs 10000-19999 for progress
  static const int _successNotificationIdStart =
      20000; // IDs 20000-29999 for success
  static const int _failureNotificationIdStart =
      30000; // IDs 30000-39999 for failure

  /// Starts tracking a batch of file tasks for background processing
  Future<void> startBackgroundTracking(String groupId) async {
    BackgroundTaskRepository.instance.add(groupId);

    // Initially display notification for the starting batch
    await _createOrUpdateBatchNotification(groupId);

    // Schedule a background task if not already running
    await _scheduleBackgroundTask();
  }

  /// Schedule a one-off or periodic background task based on the situation
  Future<void> _scheduleBackgroundTask() async {
    // Schedule a one-off task that will run in 15 seconds
    await Workmanager().registerOneOffTask(
      taskName,
      taskName,
      initialDelay: const Duration(seconds: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );

    // Also register a periodic task that will run every 15 minutes (minimum allowed)
    // to ensure we don't miss any updates if the one-off task fails
    await Workmanager().registerPeriodicTask(
      periodicTaskName,
      periodicTaskName,
      frequency: const Duration(minutes: 1), // Minimum allowed by Android
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Stop tracking a batch of file tasks
  Future<void> stopBackgroundTracking(String groupId) async {
    BackgroundTaskRepository.instance.remove(groupId);

    // Cancel notification
    await AwesomeNotifications().cancel(_getProgressNotificationId(groupId));

    // Cancel background tasks if no more active batches
    if (BackgroundTaskRepository.instance.value.isEmpty) {
      await Workmanager().cancelByUniqueName(taskName);
      await Workmanager().cancelByUniqueName(periodicTaskName);
    }
  }

  /// Get active batch IDs
  Future<Set<String>> getActiveBatchIds() async =>
      BackgroundTaskRepository.instance.value;

  /// Create or update a notification for a batch
  Future<void> _createOrUpdateBatchNotification(String groupId) async {
    // Load tasks from shared preferences (similar to what TaskManagementService does)
    final TaskManagementService taskService = TaskManagementService.instance;

    final tasks = taskService.getTasksByGroupId(groupId);
    if (tasks.isEmpty) {
      return;
    }

    // Calculate batch progress
    int totalBytes = 0;
    int transferredBytes = 0;
    bool hasError = false;
    bool allCompleted = true;
    String batchName = 'File Transfer';

    for (final task in tasks) {
      totalBytes += task.totalBytes;
      transferredBytes += task.bytesTransferred;

      if (task.isError) {
        hasError = true;
      }

      if (!task.isComplete && !task.isCached) {
        allCompleted = false;
      }

      // Get batch name from groupInfo
      if (task.group.name != null) {
        batchName = task.group.name!;
      }
    }

    final progress = totalBytes > 0 ? (transferredBytes / totalBytes) * 100 : 0;
    final progressInt = progress.round();

    // Determine notification content based on state
    if (hasError) {
      // Error notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _getFailureNotificationId(groupId),
          channelKey: notificationChannelKey,
          title: '$batchName Failed',
          body: 'Some files could not be transferred. Tap to view details.',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Error,
        ),
        actionButtons: [
          NotificationActionButton(key: 'VIEW_DETAILS', label: 'View Details'),
        ],
      );
    } else if (allCompleted) {
      // Success notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _getSuccessNotificationId(groupId),
          channelKey: notificationChannelKey,
          title: '$batchName Completed',
          body:
              'All files have been transferred successfully. Tap to view details.',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Transport,
        ),
        actionButtons: [
          NotificationActionButton(key: 'VIEW_DETAILS', label: 'View Details'),
        ],
      );
    } else {
      // Progress notification
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _getProgressNotificationId(groupId),
          channelKey: notificationChannelKey,
          title: '$batchName in Progress',
          body: 'Transferring files: $progressInt% complete',
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progressInt.toDouble(),
          locked: true,
          category: NotificationCategory.Progress,
        ),
        actionButtons: [
          NotificationActionButton(key: 'VIEW_DETAILS', label: 'View Details'),
        ],
      );

      // Store last progress update time
      final prefs = await SharedPreferences.getInstance();
      final lastUpdates = prefs.getString(_lastProgressUpdateKey);
      final Map<String, dynamic> updates = lastUpdates != null
          ? jsonDecode(lastUpdates) as Map<String, dynamic>
          : {};

      updates[groupId] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_lastProgressUpdateKey, jsonEncode(updates));
    }
  }

  // Get notification ID for progress
  int _getProgressNotificationId(String groupId) {
    return _progressNotificationIdStart + groupId.hashCode % 10000;
  }

  // Get notification ID for success
  int _getSuccessNotificationId(String groupId) {
    return _successNotificationIdStart + groupId.hashCode % 10000;
  }

  // Get notification ID for failure
  int _getFailureNotificationId(String groupId) {
    return _failureNotificationIdStart + groupId.hashCode % 10000;
  }

  static Future<void> onBackgroundExecute(
    Map<String, dynamic>? inputData,
  ) async {
    // Initialize services
    final BackgroundTransferService service = BackgroundTransferService();
    final TaskManagementService taskService = TaskManagementService.instance;

    try {
      // Get active batches
      final activeBatchIds = await service.getActiveBatchIds();

      // Check progress for each active batch
      for (final groupId in activeBatchIds) {
        final tasks = taskService.getTasksByGroupId(groupId);

        // Check if batch is done or has errors
        bool hasError = false;
        bool allCompleted = true;

        for (final task in tasks) {
          if (task.isError) {
            hasError = true;
          }

          if (!task.isComplete && !task.isCached) {
            allCompleted = false;
          }
        }

        // Update notification for this batch
        await service._createOrUpdateBatchNotification(groupId);

        // If all tasks are done or errored, stop tracking this batch
        if (hasError || allCompleted) {
          await service.stopBackgroundTracking(groupId);
        }
      }

      // Re-schedule a one-off task if there are still active batches
      if (activeBatchIds.isNotEmpty) {
        await service._scheduleBackgroundTask();
      }
    } catch (e) {
      print('Error in background task: $e');
      rethrow;
    }
  }
}
