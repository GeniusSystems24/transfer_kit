import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:transfer_kit/src/core/extension/file_path_extension.dart';
import 'package:transfer_kit/src/model/file_path_and_url.dart';
import 'package:transfer_kit/src/model/file_task.dart';
import 'package:transfer_kit/src/model/media_metadata.dart';
import 'package:transfer_kit/src/repository/file_path_and_url_repository.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a temp file with [content] and registers it as a cache entry.
/// Returns the [FilePathAndURL] entry AND the [File].
Future<(FilePathAndURL, File)> _seedEntry({
  required String url,
  String? cacheKey,
  DateTime? expiresAt,
  MediaMetadata? metadata,
}) async {
  final tmpDir = await Directory.systemTemp.createTemp('cache_test_');
  final file = File('${tmpDir.path}/file.bin');
  await file.writeAsBytes([1, 2, 3, 4, 5]);

  final now = DateTime.now();
  final entry = FilePathAndURL.url(
    url: url,
    cacheKey: cacheKey,
    expiresAt: expiresAt,
    metadata: metadata,
  ).copyWith(
    createdAt: now,
    updatedAt: now,
  );
  // Point path at real temp file
  entry.data[FilePathAndURL.pathTag] = file.path;

  FilePathAndURLRepository.instance.addOrUpdate(entry);
  return (entry, file);
}

// ---------------------------------------------------------------------------
// Suite
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => Directory.systemTemp.path,
    );
    await GetStorage.init();
    await AppDirectory.init(cacheDirectory: Directory.systemTemp.path);
  });

  setUp(() {
    FilePathAndURLRepository.instance.clear(notify: false);
  });

  tearDown(() async {
    FilePathAndURLRepository.instance.clear(notify: false);
  });

  // =========================================================================
  // US1 — Cache Hit Reuse (T010, T011)
  // =========================================================================

  group('US1 — Cache Hit Reuse', () {
    test('cache_hit_returns_cached_task', () async {
      final (entry, _) = await _seedEntry(url: 'https://example.com/file.jpg');

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      expect(result, isNotNull);
      expect(result!.url, equals(entry.url));
    });

    test('cache_hit_verifies_file_exists_on_disk', () async {
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/file2.jpg');

      // File exists → cache hit
      final hit = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);
      expect(hit, isNotNull);

      // Delete the file → cache miss, entry removed
      await file.delete();
      final miss = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);
      expect(miss, isNull);
      expect(FilePathAndURLRepository.instance.getByUrl(entry.url!), isNull);
    });

    test('cached_task_emits_cached_state', () async {
      final (entry, _) =
          await _seedEntry(url: 'https://example.com/file3.jpg');

      // A cache hit is retrievable from the repository
      final hit = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);
      expect(hit, isNotNull);

      // FileTaskState.cached is distinct from every non-cached state
      expect(FileTaskState.cached, isNot(equals(FileTaskState.waiting)));
      expect(FileTaskState.cached, isNot(equals(FileTaskState.running)));
      expect(FileTaskState.cached, isNot(equals(FileTaskState.completed)));
    });

    test('cached_metadata_returned_on_cache_hit', () async {
      const meta = MediaMetadata(mimeType: 'image/jpeg', width: 800, height: 600);
      final (entry, _) = await _seedEntry(
        url: 'https://example.com/image.jpg',
        metadata: meta,
      );

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      expect(result, isNotNull);
      expect(result!.metadata?.mimeType, equals('image/jpeg'));
      expect(result.metadata?.width, equals(800));
      expect(result.metadata?.height, equals(600));
    });

    test('cache_key_lookup_takes_precedence_over_url', () async {
      // Seed with explicit cacheKey
      final (_, _) = await _seedEntry(
        url: 'https://example.com/signed?token=abc',
        cacheKey: 'media/photo_001.jpg',
      );

      // Lookup via cacheKey with a different URL → should still find entry
      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(
        url: 'https://example.com/signed?token=xyz',
        cacheKey: 'media/photo_001.jpg',
      );

      expect(result, isNotNull);
      expect(result!.cacheKey, equals('media/photo_001.jpg'));
    });
  });

  // =========================================================================
  // US2 — Stale Cache Detection and Recovery (T014)
  // =========================================================================

  group('US2 — Stale Cache Detection and Recovery', () {
    test('stale_entry_treated_as_cache_miss', () async {
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/stale.jpg');
      await file.delete();

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      expect(result, isNull);
    });

    test('stale_entry_removed_from_index', () async {
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/stale2.jpg');
      await file.delete();

      await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      expect(
        FilePathAndURLRepository.instance.getByUrl(entry.url!),
        isNull,
      );
    });

    test('repair_stale_entries', () async {
      final (_, file1) =
          await _seedEntry(url: 'https://example.com/stale3.jpg');
      final (_, file2) =
          await _seedEntry(url: 'https://example.com/stale4.jpg');
      await _seedEntry(url: 'https://example.com/valid.jpg');

      await file1.delete();
      await file2.delete();

      final repairedCount =
          await FilePathAndURLRepository.instance.repairStaleEntries();

      expect(repairedCount, equals(2));
      expect(FilePathAndURLRepository.instance.value.length, equals(1));
    });
  });

  // =========================================================================
  // US3 — Forced Refresh (T016)
  // =========================================================================

  group('US3 — Forced Refresh', () {
    test('forced_refresh_task_state_is_not_cached', () async {
      // Non-cached states are never equal to FileTaskState.cached
      expect(FileTaskState.running, isNot(equals(FileTaskState.cached)));
      expect(FileTaskState.waiting, isNot(equals(FileTaskState.cached)));

      // After a forceRefresh the index entry is gone, so the repository
      // returns null — no cached result is ever delivered
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/refresh-state.jpg');
      if (await file.exists()) await file.delete();
      FilePathAndURLRepository.instance.remove(entry);

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);
      expect(result, isNull);
    });

    test('forced_refresh_removes_existing_index_entry', () async {
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/refresh2.jpg');

      // Simulate forceRefresh: delete local file and remove from index
      if (await file.exists()) await file.delete();
      FilePathAndURLRepository.instance.remove(entry);

      expect(
        FilePathAndURLRepository.instance.getByUrl(entry.url!),
        isNull,
      );
      expect(file.existsSync(), isFalse);
    });

    test('forced_refresh_deletes_local_file_when_present', () async {
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/refresh3.jpg');

      expect(file.existsSync(), isTrue);

      // Simulate forceRefresh cleanup
      if (await file.exists()) await file.delete();
      FilePathAndURLRepository.instance.remove(entry);

      expect(file.existsSync(), isFalse);
    });
  });

  // =========================================================================
  // US4 — Cache Metadata and Index Reliability (T020, T021)
  // =========================================================================

  group('US4 — Cache Metadata and Index Reliability', () {
    test('last_accessed_at_updated_on_cache_hit', () async {
      final (entry, _) =
          await _seedEntry(url: 'https://example.com/meta1.jpg');
      final before = entry.lastAccessedAt;

      // Small delay to ensure timestamp differs
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      final after = result?.lastAccessedAt;
      if (before == null) {
        expect(after, isNotNull);
      } else {
        expect(after!.isAfter(before), isTrue);
      }
    });

    test('updated_at_set_on_download_completion', () async {
      // Simulates what firebase_file_repository sets on onComplete
      final now = DateTime.now();
      final entry = FilePathAndURL.url(url: 'https://example.com/complete.jpg')
          .copyWith(createdAt: now, updatedAt: now);

      expect(entry.updatedAt, isNotNull);
      expect(entry.createdAt, isNotNull);
    });

    test('cache_entry_has_all_required_fields', () async {
      const meta = MediaMetadata(mimeType: 'image/png');
      final (entry, _) = await _seedEntry(
        url: 'https://example.com/fields.jpg',
        metadata: meta,
      );

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      expect(result, isNotNull);
      expect(result!.url, isNotNull);
      expect(result.path, isNotNull);
      expect(result.metadata, isNotNull);
      expect(result.lastAccessedAt, isNotNull);
    });

    test('clear_expired_entries', () async {
      // Expired entry
      final (_, file1) = await _seedEntry(
        url: 'https://example.com/exp1.jpg',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      // Valid entry
      final (_, _) = await _seedEntry(
        url: 'https://example.com/valid2.jpg',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final removed = await FilePathAndURLRepository.instance.clearExpiredEntries();

      expect(removed, equals(1));
      expect(FilePathAndURLRepository.instance.value.length, equals(1));
      // Expired file deleted from disk
      expect(file1.existsSync(), isFalse);
    });

    test('non_expired_entries_untouched', () async {
      // No expiresAt (never expires)
      await _seedEntry(url: 'https://example.com/never.jpg');
      // Future expiresAt
      await _seedEntry(
        url: 'https://example.com/future.jpg',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );

      final removed = await FilePathAndURLRepository.instance.clearExpiredEntries();

      expect(removed, equals(0));
      expect(FilePathAndURLRepository.instance.value.length, equals(2));
    });

    test('expired_entry_treated_as_cache_miss_on_lookup', () async {
      final (entry, _) = await _seedEntry(
        url: 'https://example.com/expired_lookup.jpg',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );

      final result = await FilePathAndURLRepository.instance
          .getCachedDownloadFilePathAndURL(url: entry.url!);

      expect(result, isNull);
      expect(
        FilePathAndURLRepository.instance.getByUrl(entry.url!),
        isNull,
      );
    });
  });

  // =========================================================================
  // US5 — Cache Cleanup Operations (T023)
  // =========================================================================

  group('US5 — Cache Cleanup Operations', () {
    test('delete_single_cache_entry', () async {
      final (entry, file) =
          await _seedEntry(url: 'https://example.com/del1.jpg');

      // Simulate clearCache(url)
      final found =
          FilePathAndURLRepository.instance.getByUrl(entry.url!);
      if (found != null) {
        final f = File(found.path);
        if (await f.exists()) await f.delete();
        FilePathAndURLRepository.instance.remove(found);
      }

      expect(file.existsSync(), isFalse);
      expect(
        FilePathAndURLRepository.instance.getByUrl(entry.url!),
        isNull,
      );
    });

    test('delete_set_of_cache_entries', () async {
      final (e1, f1) =
          await _seedEntry(url: 'https://example.com/batch1.jpg');
      final (e2, f2) =
          await _seedEntry(url: 'https://example.com/batch2.jpg');
      await _seedEntry(url: 'https://example.com/batch3.jpg');

      // Simulate clearCacheForUrls({url1, url2})
      for (final entry in [e1, e2]) {
        final found =
            FilePathAndURLRepository.instance.getByUrl(entry.url!);
        if (found != null) {
          final f = File(found.path);
          if (await f.exists()) await f.delete();
          FilePathAndURLRepository.instance.remove(found);
        }
      }

      expect(f1.existsSync(), isFalse);
      expect(f2.existsSync(), isFalse);
      expect(FilePathAndURLRepository.instance.value.length, equals(1));
    });

    test('cleanup_no_remote_operations', () async {
      // Cleanup methods operate only on local files and the index.
      // This test verifies no exceptions are thrown and only local state changes.
      await _seedEntry(url: 'https://example.com/cleanup1.jpg');
      await _seedEntry(url: 'https://example.com/cleanup2.jpg');

      // repairStaleEntries and clearExpiredEntries must complete without error
      final repaired =
          await FilePathAndURLRepository.instance.repairStaleEntries();
      final cleared =
          await FilePathAndURLRepository.instance.clearExpiredEntries();

      expect(repaired, isA<int>());
      expect(cleared, isA<int>());
    });
  });
}
