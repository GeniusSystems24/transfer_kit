/speckit.specify

Improve TransferKit cache behavior so downloaded files are reused reliably and never downloaded again unless the cache entry is missing, invalid, expired, manually cleared, or explicitly refreshed.

This is a maintenance and correctness task for the existing Flutter package.

## Problem

TransferKit should behave as a cache-first file transfer library.

When a file has already been downloaded successfully, future requests for the same logical file must use the local cached file instead of starting a new network download.

The package must not claim that a file is cached unless the actual local file exists and is readable.

## Goals

1. Reuse previously downloaded files.
2. Prevent duplicate downloads for the same logical file.
3. Verify local file existence before returning cached status.
4. Maintain a reliable cache index.
5. Keep cache behavior independent from UI widgets.
6. Make cache decisions observable through task state and streams.
7. Add regression tests for cache hit, cache miss, stale cache, deleted local file, forced refresh, and cleanup.
8. Update README.md and CHANGELOG.md with the final cache behavior.

## Functional Requirements

### Cache hit

When a download request is made for a file that was previously downloaded:

- TransferKit must check the cache first.
- If the local cached file exists and is valid, TransferKit must return a task with state `cached` or `completed` according to the final agreed lifecycle.
- TransferKit must not start a new network download.
- Widgets must receive the cached file quickly through the normal task stream or direct API response.

### Cache miss

When no valid local cache entry exists:

- TransferKit must create a download task.
- TransferKit must download the file.
- TransferKit must store the local file path and metadata after successful completion.
- TransferKit must update the cache index.

### Stale cache

When a cache index entry exists but the actual file is missing:

- TransferKit must treat it as a cache miss.
- TransferKit must clean or repair the stale cache entry.
- TransferKit must download the file again only because the local file is actually missing.

### Forced refresh

When the caller explicitly requests refresh:

- TransferKit must bypass the cache.
- TransferKit must redownload the file.
- TransferKit must replace or update the existing local cache entry.
- Existing task state must remain consistent.

### Cache key

TransferKit must define a stable cache key strategy.

Possible key sources:
- original URL,
- normalized URL,
- caller-provided cache key,
- destination path,
- file hash if available.

The final implementation must avoid unsafe assumptions such as using temporary signed URLs as permanent cache identity unless explicitly documented.

### Cache metadata

Cache entries should include enough information to validate and reuse files:

- cache key,
- original URL or source identifier,
- local path,
- file size if known,
- mime type if known,
- createdAt,
- updatedAt,
- lastAccessedAt,
- expiresAt if expiration is enabled,
- metadata if available.

### Cache cleanup

Cache cleanup must support:

- deleting a single cached file,
- deleting a set of cached files,
- clearing expired files,
- enforcing max cache size if enabled,
- repairing stale entries whose files no longer exist.

Cache cleanup must never delete remote files.

## Non-Goals

- Do not rewrite the whole package.
- Do not introduce a new database unless justified.
- Do not change unrelated widgets.
- Do not remove provider-specific code in this task unless needed for cache correctness.
- Do not implement new notification features in this task.

## User Stories

1. As a Flutter developer, when I display the same image in multiple screens, I want TransferKit to reuse the downloaded file so that the app does not waste bandwidth.

2. As a user, when I reopen the app, I expect previously downloaded files to open quickly from local cache.

3. As a developer, when a cached file was deleted manually or by the OS, I want TransferKit to detect that and redownload it safely.

4. As a developer, when I explicitly request refresh, I want TransferKit to redownload the file even if a cached copy exists.

5. As a developer, I want cache behavior to be testable and independent from UI widgets.

## Acceptance Criteria

- A previously downloaded file is not downloaded again when the local cache file exists.
- A stale cache entry is detected and repaired.
- Forced refresh bypasses cache.
- Cache metadata is updated after a successful download.
- Cache cleanup does not delete remote files.
- All cache behavior is covered by tests where practical.
- README.md documents the cache-first behavior.
- CHANGELOG.md lists the change.
