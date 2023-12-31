# GOV.UK Dependabot Merger

This repository runs a daily GitHub action that automatically approves and merges certain Dependabot PRs for opted-in GOV.UK repos, according to [strict criteria set out in RFC-156](https://github.com/alphagov/govuk-rfcs/blob/main/rfc-156-auto-merge-internal-prs.md), summarised below:

> This service should ONLY be used to merge internal dependencies (excluding 'major' version updates). It should also only be enabled on repos which have sufficient test coverage (such as continuously deployed apps, as these have to reach 95% coverage). Deviate from the guidance at your own risk.

Note that govuk-dependabot-merger will avoid merging a PR if it has a failing GitHub Action CI build called `test-ruby`, [as per convention](https://docs.publishing.service.gov.uk/manual/test-and-build-a-project-with-github-actions.html#branch-protection-rules). It will also avoid running altogether on weekends and bank holidays.

## Usage

To opt into the govuk-dependabot-merger service, first create a `.govuk_dependabot_merger.yml` config file at the root of your repository. Configure the file with an array of dependencies and associated semver bumps that you would like the service to merge for you.

For example:

```yaml
api_version: 1
auto_merge:
  - dependency: govuk_publishing_components
    allowed_semver_bumps:
      - patch
      - minor
  - dependency: rubocop-govuk
    allowed_semver_bumps:
      - patch
      - minor
```

After you've merged your config file into your main branch, you just need to add your repository to the [config/repos_opted_in.yml](config/repos_opted_in.yml) list in govuk-dependabot-merger.

## Technical documentation

### Running the test suite

To run the linter:

```
bundle exec rubocop
```

To run the tests:

```
bundle exec rspec
```

### Using the merger locally

The repo expects an `AUTO_MERGE_TOKEN` environment variable to be defined. This should be a GitHub API token [with sufficient scope](./docs/adr/03-access-token-scope.md).

You can then run the merger with:

```
bundle exec ruby bin/merge_dependabot_prs.rb
```

The repo also ships with a "doctor" script to help you to debug individual PRs and why they did or did not auto-merge.

```
bundle exec ruby bin/pr_doctor.rb https://github.com/alphagov/content-data-api/pull/1996
```

### Further documentation

- [ADR 1: Limited team access to avoid privilege escalation](./docs/adr/01-limited-team-access.md)
- [ADR 2: Do not merge subdependency updates](./docs/adr/02-do-not-merge-subdependencies.md)
- [ADR 3: GitHub Access Token scope](./docs/adr/03-access-token-scope.md)
- [ADR 4: Ignore subdependencies](./docs/adr/04-ignore-subdependencies.md)

## Licence

[MIT LICENCE](LICENCE).
