/speckit.implement

Implement the cache reuse and local cache correctness task.

Rules:

- Do not rewrite TransferKit from scratch.
- Do not remove Firebase in this task.
- Do not change notification behavior in this task.
- Preserve public API compatibility unless a small additive API is approved.
- Add or update tests with each behavior change.
- Keep implementation incremental.

Implementation order:

1. Run format/analyze/tests to establish baseline.
2. Audit current cache behavior.
3. Implement cache key resolution.
4. Implement cache-first lookup.
5. Implement stale cache repair.
6. Implement forced refresh behavior if approved.
7. Implement cleanup behavior.
8. Add tests.
9. Update README.md and CHANGELOG.md.
10. Run:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`

Stop and report if:
- Existing tests fail before changes.
- Cache behavior depends on unclear requirements.
- A breaking API change appears necessary.
- Signed URL behavior cannot be solved safely without caller-provided cache keys.
