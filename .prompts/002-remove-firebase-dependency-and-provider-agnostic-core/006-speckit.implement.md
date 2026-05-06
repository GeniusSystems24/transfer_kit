/speckit.implement

Implement Firebase removal and provider-agnostic transfer core.

Rules:

- Do not implement notification redesign in this task.
- Do not change cache policy except what is necessary for provider independence.
- Preserve public APIs where practical.
- Treat Firebase removal as a potentially breaking change.
- Add tests using fake drivers.
- Remove Firebase imports only after generic contracts are working.
- Update README.md and CHANGELOG.md.

Implementation order:

1. Run baseline checks:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`

2. Audit Firebase coupling.

3. Add generic transfer contracts.

4. Add fake transfer drivers for tests.

5. Refactor download flow to use generic driver.

6. Refactor upload flow to use generic driver.

7. Refactor task control operations to capability-based provider operations.

8. Remove or isolate Firebase-specific factory and dependencies.

9. Update examples and documentation.

10. Run:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`

Stop and report if:
- Removing Firebase requires a major version decision.
- Current public API cannot be preserved.
- Background transfer cannot be made provider-agnostic safely.
- Tests reveal lifecycle regressions.
