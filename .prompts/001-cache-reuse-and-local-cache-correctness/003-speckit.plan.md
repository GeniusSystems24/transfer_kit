/speckit.plan

Create a technical implementation plan for TransferKit cache reuse and local cache correctness.

## Tech Stack

- Flutter / Dart
- Existing TransferKit architecture
- Existing repository/service pattern
- Existing task model and task streams
- Existing local persistence mechanism unless a better approach is justified
- `flutter_test` for tests

## Architecture Direction

Introduce or refine a dedicated cache layer that is separate from UI widgets and provider-specific download logic.

Recommended components:

1. `CacheKeyResolver`
   - Builds a stable cache key from URL/source/cacheKey.
   - Handles normalization rules.

2. `CacheIndexRepository`
   - Stores cache metadata.
   - Looks up entries by cache key.
   - Repairs/removes stale entries.

3. `CacheFileStore`
   - Owns local cache paths.
   - Verifies local file existence.
   - Deletes local cached files safely.
   - Prevents path traversal.

4. `CachePolicy`
   - Determines expiration.
   - Determines max-size cleanup behavior.
   - Supports forced refresh.

5. `DownloadOrchestrator`
   - Checks cache before network.
   - Uses stream sharing for in-flight downloads.
   - Writes cache metadata after success.
   - Emits consistent task state.

## Implementation Phases

### Phase 1: Audit current cache behavior

- Inspect current cache path generation.
- Inspect `isFileCached`.
- Inspect `getCachedFilePath`.
- Inspect download completion metadata persistence.
- Inspect widgets that use cache behavior.
- Document current gaps.

### Phase 2: Define cache identity and state behavior

- Decide cache key strategy.
- Decide whether cache hit emits `cached` or `completed`.
- Decide task persistence behavior on cache hit.
- Add tests for expected behavior before implementation where possible.

### Phase 3: Implement cache lookup before network

- Add cache lookup before creating network download tasks.
- Verify local file existence.
- Return cached task without network download.
- Ensure streams emit cached/completed state consistently.

### Phase 4: Repair stale entries

- If metadata exists but file is missing, remove or mark stale.
- Continue with normal download.
- Add regression test.

### Phase 5: Forced refresh

- Add explicit refresh option if not already available.
- Bypass cache only when requested.
- Preserve previous cache until new download succeeds if possible.

### Phase 6: Cache cleanup

- Implement or validate single-file cleanup.
- Implement or validate expired cleanup.
- Implement or validate max-size cleanup.
- Ensure cleanup never affects remote files.

### Phase 7: Tests and documentation

- Add tests for cache hit, miss, stale, refresh, cleanup.
- Update README.md.
- Update CHANGELOG.md.

## Data Model

Recommended cache entry:

```dart
class TransferCacheEntry {
  final String cacheKey;
  final String? sourceUrl;
  final String localPath;
  final int? fileSize;
  final String? mimeType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;
  final DateTime? expiresAt;
  final Map<String, dynamic>? metadata;
}
```

## Public API Considerations

Possible additions:

```dart
Future<FileTask> downloadTask({
  required FilePathAndURL filePathAndUrl,
  required String taskId,
  bool autoStart = true,
  FileGroupInfo? group,
  bool forceRefresh = false,
  String? cacheKey,
});
```

Avoid breaking existing calls.

## Test Plan

- Cache hit does not create network task.
- Cache miss creates network task.
- Stale cache entry is repaired.
- Forced refresh bypasses cache.
- Failed forced refresh does not destroy previous cache unless explicitly intended.
- Cache cleanup removes local file and cache index entry.
- Concurrent requests share in-flight transfer.

## Risks

- Changing cache behavior may affect widgets.
- Signed URLs may make URL-based cache keys unstable.
- Hash validation may be too expensive for large files.
- Existing docs may overstate cache behavior.

## Rollback Strategy

- Keep old behavior behind default path until tests pass.
- Introduce new optional flags without removing existing API.
- Document behavior changes clearly.
