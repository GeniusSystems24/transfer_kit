/speckit.clarify

Clarify notification control and design requirements.

Ask questions in English and Arabic.

Focus on:

## Notification Scope

1. Should notifications be enabled by default or disabled by default?
2. Should progress notifications be shown for all transfers or only background transfers?
3. Should cache hits show notifications?

## Notification Package

4. Should TransferKit continue using `awesome_notifications`?
5. Should notifications be hidden behind a generic adapter?
6. Should apps be able to provide their own notification service?

## Permission Behavior

7. Should TransferKit request notification permission automatically?
8. Should permission handling be the app's responsibility?
9. What should happen if notification permission is denied?

## Design Customization

10. Which notification fields should be customizable?
11. Should notification templates support localization?
12. Should upload and download have separate templates?
13. Should success, error, paused, cancelled, and retry states have separate templates?

## Progress Updates

14. How often should progress notifications update?
15. Should updates be throttled by time, percentage change, or both?
16. Should progress notifications be silent?

## Actions

17. Should notifications include actions like pause, resume, cancel, retry?
18. If actions are supported, should they call TransferKit task controls?
19. Are notification actions required for the first version?

## Batch Transfers

20. Should batch transfers use grouped notifications?
21. Should each file have a separate notification?
22. Should developers choose between per-file and group notification modes?

## Platform Support

23. Which platforms must be supported?
24. Should unsupported platforms silently skip notifications or throw?
25. Should platform limitations be documented in README?

Return:
- English question
- Arabic translation
- why this matters
- recommended default if unanswered
