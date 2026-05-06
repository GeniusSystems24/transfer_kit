/speckit.clarify

Clarify the Firebase removal and provider-agnostic transfer core task.

Ask questions in English and Arabic.

Focus on:

## Scope

1. Should Firebase support be completely removed, or moved to a separate optional adapter?
2. Should this package become fully provider-agnostic in the same package, or should a monorepo/multi-package approach be used?
3. Should current Firebase APIs remain temporarily deprecated or be removed immediately?

## Versioning

4. Is this a breaking change requiring a major version bump?
5. What should the next version be: 2.x minor, 3.0.0, or another version?
6. Should a migration guide be mandatory before implementation is accepted?

## Providers

7. What should be the default provider after Firebase removal?
8. Should TransferKit include an HTTP download provider by default?
9. Should upload be generic only through an injected provider?
10. Should local file copy be supported as a built-in provider for testing and local workflows?

## API Compatibility

11. Which public APIs must remain unchanged?
12. Are Firebase URL-specific helpers allowed to remain as deprecated wrappers?
13. Should `FilePathAndURL` be renamed later, or preserved for compatibility?

## Capabilities

14. How should the core behave when a provider does not support pause?
15. How should the core behave when a provider does not support resume?
16. How should the core behave when a provider does not support progress?
17. Should unsupported actions throw, return false, or update task state to error?

## Background Transfers

18. Should provider capability include background support?
19. Should background transfer be removed until implemented generically?
20. Should background support be documented as provider-dependent?

## Testing

21. What fake provider behaviors are required for tests?
22. Should tests simulate success, failure, progress, pause, resume, cancel, retry, and timeout?

## Documentation

23. Should README.md be rewritten from Firebase-focused to provider-agnostic?
24. Should Firebase examples be removed or moved to a migration/adapter section?

Return:
- English question
- Arabic translation
- why it matters
- recommended default if unanswered
