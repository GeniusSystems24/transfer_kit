# Feature Specification: Cache Reuse and Local Cache Correctness

**Feature Branch**: `001-cache-reuse-correctness`
**Created**: 2026-05-07
**Status**: Draft
**Input**: User description: "Improve TransferKit cache behavior so downloaded files are reused reliably and never downloaded again unless the cache entry is missing, invalid, expired, manually cleared, or explicitly refreshed."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Cache Hit Reuse (Priority: P1)

A Flutter developer displays the same file (e.g., an image or document) across multiple screens. When the file was already downloaded once, TransferKit must return the cached local file immediately without starting any network download.

**Why this priority**: Eliminating redundant downloads is the core value of this feature. It directly saves bandwidth and improves perceived app performance.

**Independent Test**: Can be fully tested by downloading a file once, then requesting the same file again and confirming zero network requests are made; delivers clear bandwidth savings and faster load times.

**Acceptance Scenarios**:

1. **Given** a file has been downloaded successfully, **When** the same file is requested using the same cache key, **Then** TransferKit returns the cached local file without initiating a network request.
2. **Given** a previously downloaded file exists locally, **When** TransferKit evaluates the cache, **Then** it physically verifies the file exists on disk before reporting a cached state.
3. **Given** multiple widgets request the same cached file simultaneously, **When** the cache lookup succeeds, **Then** all callers receive the cached file path and no duplicate downloads are initiated.

---

### User Story 2 - Stale Cache Detection and Recovery (Priority: P2)

When the cache index records a file but the actual local file has been deleted (by the user, OS, or storage reclaim), TransferKit must detect the inconsistency and re-download the file transparently.

**Why this priority**: A stale index entry pointing to a missing file causes silent failures and broken UI. This scenario is common in production — the OS can evict files without the app's knowledge.

**Independent Test**: Can be fully tested by deleting a cached file from disk after recording its index entry, then requesting the same file and confirming it is re-downloaded and the index is repaired.

**Acceptance Scenarios**:

1. **Given** a cache index entry exists for a file, **When** the local file no longer exists on disk, **Then** TransferKit treats this as a cache miss, not a cache hit.
2. **Given** a stale entry is detected, **When** TransferKit processes the request, **Then** it removes or repairs the stale entry before starting a new download.
3. **Given** a stale entry has been repaired and the file re-downloaded, **When** the download completes, **Then** the cache index is updated with the new valid local path and metadata.

---

### User Story 3 - Forced Refresh (Priority: P3)

A developer explicitly requests a fresh download of a file even though a valid cached copy exists. TransferKit bypasses the cache, downloads the latest version, and replaces the existing cached entry.

**Why this priority**: Required for content that may change at source (e.g., updated documents, images replaced in place).

**Independent Test**: Can be fully tested by downloading a file, then requesting a forced refresh and confirming a network download occurs and the cache entry is updated.

**Acceptance Scenarios**:

1. **Given** a valid cached file exists, **When** a forced refresh is requested, **Then** TransferKit downloads the file from the network regardless of cache state.
2. **Given** a forced refresh download completes, **When** the new file is saved locally, **Then** the cache entry is replaced with the updated path and fresh metadata.
3. **Given** a forced refresh is in progress, **When** the task state is observed, **Then** it reflects an active download — not a cached state.

---

### User Story 4 - Cache Metadata and Index Reliability (Priority: P4)

After every successful download, TransferKit records a complete, validated cache entry containing all information needed for future cache decisions and file validation.

**Why this priority**: Without reliable metadata, cache hit decisions cannot be made confidently and cache cleanup cannot operate correctly.

**Independent Test**: Can be tested by downloading a file and asserting all required metadata fields are present and accurate in the persisted cache entry.

**Acceptance Scenarios**:

1. **Given** a download completes successfully, **When** the cache index is written, **Then** the entry contains: cache key, source URL, local path, file size (if known), mime type (if known), `createdAt`, `updatedAt`, and `lastAccessedAt`.
2. **Given** a cache entry has an `expiresAt` value in the past, **When** a cache lookup is performed, **Then** TransferKit treats the entry as a cache miss.
3. **Given** a cache hit occurs, **When** the file is returned to the caller, **Then** `lastAccessedAt` on the cache entry is updated to the current time.

---

### User Story 5 - Cache Cleanup Operations (Priority: P5)

A developer can selectively clean the cache — removing a single file, a group of files, all expired entries, or repairing stale index entries — without any risk of deleting remote files.

**Why this priority**: Storage management is necessary for long-running apps. The hard constraint that remote files are never deleted is a safety requirement.

**Independent Test**: Can be tested by populating multiple cache entries and running each cleanup operation independently, confirming only local files and index entries are affected.

**Acceptance Scenarios**:

1. **Given** multiple cached files exist, **When** single-file deletion is requested, **Then** only that file's local copy and its index entry are removed.
2. **Given** cache entries with past expiry dates exist, **When** expired-entry cleanup runs, **Then** only expired entries and their local files are removed; non-expired entries are untouched.
3. **Given** stale entries exist (index records files that are missing on disk), **When** stale-entry repair runs, **Then** those index entries are removed without touching any remote storage.
4. **Given** any cleanup operation runs, **When** it completes, **Then** no remote file operations are performed.

---

### Edge Cases

- What happens when the app loses connectivity mid-download after a cache miss?
- How does the system handle two simultaneous first-time requests for the same uncached file?
- What happens when the cache directory is full and a new file cannot be written?
- How does the system handle a cache key collision between semantically different URLs?
- What happens when a cached file exists on disk but cannot be read (corrupted or permission denied)?
- How does forced refresh behave when the network is unavailable?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: TransferKit MUST check the local cache index before initiating any network download.
- **FR-002**: TransferKit MUST physically verify that the local cached file exists on disk and is readable before reporting a cached state.
- **FR-003**: TransferKit MUST NOT initiate a new network download when a valid, verified local cached file exists for the requested cache key.
- **FR-004**: TransferKit MUST define and document a stable cache key strategy; the default key is the normalized source URL; callers MAY provide an explicit cache key to override the default.
- **FR-005**: TransferKit MUST treat a cache index entry whose local file is missing as a cache miss and repair or remove the stale entry before re-downloading.
- **FR-006**: TransferKit MUST support a forced refresh mode that bypasses the cache and replaces the local cache entry upon successful download completion.
- **FR-007**: TransferKit MUST update `updatedAt` after a download or cache entry modification, and `lastAccessedAt` after every cache hit.
- **FR-008**: TransferKit MUST persist cache entries containing: cache key, source URL, local file path, file size (when known), mime type (when known), `createdAt`, `updatedAt`, `lastAccessedAt`, and `expiresAt` (when expiration is configured).
- **FR-009**: TransferKit MUST support deleting a single cache entry and its associated local file.
- **FR-010**: TransferKit MUST support deleting a specified set of cache entries and their associated local files.
- **FR-011**: TransferKit MUST support clearing all cache entries whose `expiresAt` timestamp has passed.
- **FR-012**: TransferKit MUST support repairing stale cache entries by removing index records for files that no longer exist locally.
- **FR-013**: Cache cleanup operations MUST NOT perform any remote file deletions.
- **FR-014**: Cache state and transitions MUST be observable through task state and streams without requiring any UI widget interaction.
- **FR-015**: TransferKit MUST include regression tests covering: cache hit, cache miss, stale cache entry detection, deleted local file recovery, forced refresh, and cache cleanup.

### Key Entities

- **CacheEntry**: A record in the cache index representing one downloaded file — attributes include cache key, source URL, local file path, file size, mime type, `createdAt`, `updatedAt`, `lastAccessedAt`, `expiresAt`, and an optional metadata map.
- **CacheKey**: A stable, deterministic identifier for a cached file, derived from a normalized URL by default or supplied explicitly by the caller; transient signed URLs must not serve as the sole cache key.
- **CacheIndex**: The persistent collection of all CacheEntry records; must remain consistent with actual files on local storage.
- **DownloadTask**: Represents a download operation with observable state; state must accurately reflect whether the result originated from local cache or a network download.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A file requested for the second time is served from local cache with zero network requests, verifiable by asserting no download transport calls are made.
- **SC-002**: Every stale cache entry (index record pointing to a missing file) is detected and repaired before any response is returned; zero false "cached" states are delivered to callers.
- **SC-003**: Forced refresh always produces a new network download regardless of local cache state, verifiable by asserting that transport calls are made even when a cached file exists.
- **SC-004**: Every successful download produces a cache entry with 100% of required metadata fields populated and persisted.
- **SC-005**: All cache cleanup operations complete without any remote file operations, verified by test assertions on the transport and storage layers.
- **SC-006**: The regression test suite covers all specified cache scenarios and all tests pass on every run.
- **SC-007**: Previously downloaded files are delivered to the caller from cache in under 200ms on a mid-range device, measured from request initiation to file path delivery.

## Assumptions

- The existing local persistence mechanism (GetStorage) will be used for the cache index; a new database is not required unless proven inadequate during planning.
- Cache key defaults to the normalized source URL; callers who use signed or temporary URLs must provide an explicit stable cache key — this behavior will be documented.
- File expiration is optional and disabled by default; expiry is only enforced when `expiresAt` is explicitly set on an entry.
- Maximum cache size enforcement is out of scope for this phase and may be documented as a planned future capability.
- The cache operates exclusively on local app storage; remote storage (Firebase, CDN) is never touched by any cache operation.
- Widget layer changes are out of scope; all improvements target the library's core layer.
- Cache behavior is unit-testable without live network connections by using mocks or fakes for the download transport layer.
- The existing `completed` task state may serve as the cache-hit state, or a dedicated `cached` state may be introduced — the final lifecycle decision will be made during the planning phase.
