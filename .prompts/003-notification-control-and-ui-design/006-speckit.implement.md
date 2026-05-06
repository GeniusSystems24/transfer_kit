/speckit.implement

Implement notification control and notification UI/design improvements.

Rules:

- Do not remove Firebase in this task.
- Do not change cache policy in this task.
- Keep notifications optional.
- Keep notification logic testable with a fake adapter.
- Do not request permissions automatically unless explicitly approved.
- Avoid duplicate notifications.
- Update README.md and CHANGELOG.md.

Implementation order:

1. Run baseline:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`

2. Audit current notification logic.

3. Add notification configuration.

4. Add adapter abstraction and fake adapter.

5. Add notification policy.

6. Add default templates.

7. Add duplicate prevention and throttling.

8. Add batch/group notification behavior.

9. Add tests.

10. Update README.md and CHANGELOG.md.

11. Run:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`

Stop and report if:
- Platform notification behavior cannot be tested safely.
- Permission behavior is ambiguous.
- Notification actions require native/platform work beyond the approved scope.
