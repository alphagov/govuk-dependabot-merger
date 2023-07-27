# ADR 1: Limited team access to avoid privilege escalation

Date: 2023-07-24

## Context

As this service uses a GitHub token with the power to approve and merge PRs, we need to be careful that a bad actor can't abuse it to elevate their own privileges.

Consider a new GOV.UK developer with integration admin access. They'd join the [GOV.UK GitHub team](https://docs.publishing.service.gov.uk/manual/github-access.html#teams-in-alphagov), which gives write access to GOV.UK repos (including most private ones).

It might be possible for the developer to write to a branch of this repo, crafting some logic to extract the GitHub token, which they could then use to merge arbitrary malicious code to other GOV.UK repos and live applications. Even if it's not possible without merging said branch, it's difficult to reason about and hard to validate continuously.

## Decision

We have made the deliberate decision to restrict the "GOV.UK" group to read access only. The only group that has write access is the "GOV.UK Production Admin" group, whose members already have elevated privileges (and who can already extract the credentials for the govuk-ci account, from govuk-secrets).

## Consequences

We may need to add govuk-dependabot-merger to one of the ignore/override config files in [govuk-saas-config](https://github.com/alphagov/govuk-saas-config/tree/main/github), if there is automation in future that might grant more access than is acceptable. Any changes to that repo will need to be sensitive to the needs of this repo.
