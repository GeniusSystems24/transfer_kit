# TransferKit Spec Kit Maintenance Tasks

This package contains three separated Spec Kit task folders for improving `transfer_kit`.

## Recommended execution order

1. `001-cache-reuse-and-local-cache-correctness`
2. `002-remove-firebase-dependency-and-provider-agnostic-core`
3. `003-notification-control-and-ui-design`

## Why this order?

- Cache correctness should be stabilized first because it is central to download behavior.
- Firebase removal should be handled after cache requirements are explicit, so the new transfer core remains provider-agnostic.
- Notification control and design should come after task lifecycle and provider boundaries are clearer.

## Suggested branch names

```bash
git checkout -b 001-cache-reuse-and-local-cache-correctness
git checkout -b 002-remove-firebase-dependency-and-provider-agnostic-core
git checkout -b 003-notification-control-and-ui-design
```

## Standard Spec Kit flow per task

Run the files in each task folder in this order:

1. `001-speckit.specify.md`
2. `002-speckit.clarify.md`
3. `003-speckit.plan.md`
4. `004-speckit.tasks.md`
5. `005-speckit.analyze.md`
6. `006-speckit.implement.md`

Use the content of each file as the prompt for the matching Spec Kit command.
