/speckit.clarify

Clarify the cache reuse and local cache correctness feature before implementation.

Ask targeted questions in English and Arabic.

Focus on these ambiguity areas:

## Cache Identity

1. Should the cache key be based on the URL, a caller-provided key, a file hash, or a normalized source identifier?
2. How should TransferKit handle temporary signed URLs that change over time but point to the same file?
3. Should the caller be allowed to provide a stable `cacheKey`?

## Cache State

4. Should a reused cached file emit `FileTaskState.cached`, `FileTaskState.completed`, or both through a lifecycle transition?
5. Should cached tasks keep the original task ID or create a new task per request?
6. Should a cache hit create/update a task entry in the task repository?

## Cache Storage

7. Should cached files be stored in temporary directory, application documents directory, application support directory, or a configurable directory?
8. Should cache survive app uninstall? If not, clarify expected behavior.
9. Should cache paths be human-readable or hashed?

## Cache Validation

10. What makes a cache entry valid?
11. Should validation check only file existence, or also file size/hash?
12. Should SHA-256 validation be optional because it can be expensive for large files?

## Cache Expiration and Size

13. Should cache expiration be enabled by default?
14. Should `maxCacheSize` be enforced automatically or only during manual cleanup?
15. What eviction policy should be used: least recently used, oldest first, largest first, or custom?

## Refresh Behavior

16. Should forced refresh replace the same local file or create a new file?
17. Should forced refresh preserve old cache until the new download succeeds?
18. What should happen if forced refresh fails but the previous cached file still exists?

## Concurrency

19. If two widgets request the same uncached file at the same time, should one download be shared?
20. If one request is a forced refresh and another is a normal cache request, which behavior wins?

## Documentation

21. Which README examples must be updated?
22. Should migration notes be added for cache behavior changes?

Return the clarification questions in this format:

- English question
- Arabic translation
- Why this matters
- Recommended default answer if no answer is provided
