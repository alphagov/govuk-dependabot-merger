# ADR 3: Access Token Scope

Date: 2023-07-24

## Context

This repo requires a privileged GitHub token in order to approve and merge pull requests. Where we create this token, and what permissions we grant it, has an impact on the security of the service.

## Decision

We'll create a fine grained GitHub personal access token on the [govuk-ci](https://github.com/govuk-ci) user, with the following permissions:
- Read on metadata
- Read and write on pull requests
- Read and write on contents
- Applied to "All repositories" owned by the organisation.

This token will be used as the `AUTO_MERGE_TOKEN` repository secret for govuk-dependabot-merger.

The token will have a 1 year expiry date, expiring 24th July 2024, but this should not set a precedent. The expiry date of the next renewed token can be decided later.

## Consequences

This should not pose a privilege escalation risk, as the token is associated with govuk-ci, and [govuk-ci is only a 'member' of the alphagov org](https://github.com/orgs/alphagov/people?query=govuk-ci). The token therefore should not have the ability to write to repos owned outside of GOV.UK (or at least have no more permissions than anyone else who is a member of the alphagov org).

It might have been safer to grant access to specific named repositories we want to enable the auto-merge workflow for, but this would add a significant barrier to opting repos into the service (and we do after all want this service to be a success and to be used more widely). The act of granting permissions on a per-repo basis requires decrypting the govuk-ci password in govuk-secrets, setting up the 2FA, signing into the account and then carefully editing the scope of the token without making mistakes.
