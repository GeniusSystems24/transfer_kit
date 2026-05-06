/speckit.analyze

Analyze the cache reuse specification, plan, and tasks.

Check for:

1. Is cache identity clearly defined?
2. Is signed URL behavior clarified?
3. Is cache hit state clearly defined?
4. Are stale entries handled?
5. Is forced refresh behavior safe?
6. Is max-size cleanup either implemented or honestly documented?
7. Are tests included for hit, miss, stale, refresh, cleanup, and concurrency?
8. Does the plan avoid unrelated Firebase removal?
9. Does the plan avoid notification work?
10. Are README.md and CHANGELOG.md updates included?
11. Is the implementation backward-compatible?
12. Is there any hidden breaking change?

If any issue is found, return:
- issue
- why it matters
- suggested correction
