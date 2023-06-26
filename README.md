# GitHub Action: Dependabot Automerge

> This repository is a **Work In Progress** and should not be used in production.

Note that the only GitHub group that has write access to this repository is the GOV.UK Production Admin group.
We've deliberately avoided giving write access to the GOV.UK Production Deploy group (or similar) as otherwise there is a risk that someone in that group could escalate their own privileges.

## Technical documentation

### Usage

You'll need to create a `AUTO_MERGE_TOKEN` ENV variable, which must be a fine-grained GitHub personal access token with the following permissions:

- Read and write on pull requests
- Read and write on contents
- Read on metadata
- ...the above permissions applied to every repo that we want to enable the auto-merge workflow for.
  - This could be a manually curated list of repos (GitHub has a limit of 50) or alternatively you could have it apply to every repo or every public repo.

With that ENV variable created, you can trigger the auto-merge script with:

```
bundle exec ruby bin/merge_dependabot_prs.rb
```

> The long term aim is to store this token as a repository secret in github-action-dependabot-auto-merge, and trigger the above script on a GitHub Action crob/schedule.
> Note also that current token is linked to 'chrisbashton' and has permissions against the 'chris-test-repo' only. It will eventually be replaced with a token linked to 'govuk-ci', and with permission against more repositories.

### Running the test suite

To run the linter:

```
bundle exec rubocop
```

To run the tests:

```
bundle exec rspec
```

## Licence

[MIT LICENCE](LICENCE).
