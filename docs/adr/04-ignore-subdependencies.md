# ADR 4: Ignore subdependencies

Date: 2023-11-17

## Context

This ADR supersedes [ADR 2](./02-do-not-merge-subdependencies.md), which argued that we should ignore any Dependabot PRs that bump allowlisted dependencies, if those PRs also bump subdependencies that are not on the allowlist.

In the first three months that this service was active, [only one Dependabot PR satisfied that rule](https://github.com/alphagov/govuk-developer-docs/pull/4278), and thus the service only auto-merged a single PR.

In practice, most PRs lump in a number of subdependency updates (see [example](https://github.com/alphagov/govuk-developer-docs/pull/4238/files)). This is Bundler’s native behaviour when it updates a dependency. Bundler does allow a `--conservative` flag to `bundle update <gem name>` that prevents that, but [there's currently no equivalent config option for Dependabot](https://github.com/dependabot/dependabot-core/issues/2246).

A [Google document](https://docs.google.com/document/d/1teKe8_5nObHh0sEaLu9S1OgcX-SWRj8cjfNSg-cv5ns/edit) was written, explaining this issue and possible ways forward. It concluded that for the auto merger service to be at all useful, we'll need to relax the rules around subdependency updates.

## Decision

We've [dropped the rule](https://github.com/alphagov/govuk-dependabot-merger/pull/17) that prevents subdependency bumps.

## Consequences

This has already led to an immediate uptick in the number of PRs the auto merger will merge (see [example](https://github.com/alphagov/govuk-developer-docs/pull/4304)).

This does introduce a small but acceptable attack vector, described further in the linked Google doc.
