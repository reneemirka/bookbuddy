# Book Buddy Development Instructions

Before making changes:
1. Read docs/product-spec.md.
2. Inspect the existing implementation before modifying it.
3. Identify the milestone requested by the user.
4. Implement only that milestone.

Engineering principles:
- Book Buddy is local-first.
- SwiftData is the primary store for the personal version.
- Do not introduce cloud infrastructure unless the requested milestone requires it.
- Do not implement future milestones proactively.
- Preserve existing functionality.
- Prefer simple architecture over premature abstraction.
- External services should be isolated behind provider interfaces when introduced.
- Never commit API keys, tokens, or other secrets.
- Add/update tests for meaningful new behavior.
- Do not replace working code simply to reorganize it unless there is a concrete reason.

After completing a task:
1. Run relevant tests/build checks.
2. Explain what changed.
3. Call out any architectural decisions or assumptions.
4. Identify anything from the requested milestone that remains incomplete.
