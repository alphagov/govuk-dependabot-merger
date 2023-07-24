# ADR 2: Do not merge subdependency updates

Date: 2023-07-24

## Context

When Dependabot raises a PR to bump a dependency, it is not necessarily constrained to just that dependency.

Take this [example PR](https://github.com/alphagov/govuk-developer-docs/pull/3987/files), which bumps a patch version of internal dependency `govuk_publishing_components` but *also bumps two third-party dependencies*. Whilst these other dependencies do appear as subdependencies of `govuk_publishing_components`, no part of the `govuk_publishing_components` release references them.

I raised this with GitHub support to see if there is a Dependabot config way around this, but they explained that this is Bundler's native behaviour.

You can see the same behavior when performing the update manually using Bundler:

```sh
$ bundle info govuk_publishing_components
  * govuk_publishing_components (35.3.2)
    Summary: A gem to document components in GOV.UK frontend applications
    Homepage: https://github.com/alphagov/govuk_publishing_components
    Path: /Users/jurre/.rbenv/versions/3.1.3/lib/ruby/gems/3.1.0/gems/govuk_publishing_components-35.3.2

$ bundle update govuk_publishing_components --patch
Fetching gem metadata from https://rubygems.org/.........
Resolving dependencies...
# ... snip
Fetching govuk_publishing_components 35.3.5 (was 35.3.2)
Installing govuk_publishing_components 35.3.5 (was 35.3.2)
Bundle updated!

$ g diff
diff --git a/Gemfile.lock b/Gemfile.lock
index c383f71eb..48df3e288 100644
--- a/Gemfile.lock
+++ b/Gemfile.lock
@@ -167,7 +167,7 @@ GEM
     govuk_personalisation (0.13.0)
       plek (>= 1.9.0)
       rails (>= 6, < 8)
-    govuk_publishing_components (35.3.2)
+    govuk_publishing_components (35.3.5)
       govuk_app_config
       govuk_personalisation (>= 0.7.0)
       kramdown
@@ -291,7 +291,7 @@ GEM
       middleman-core (>= 3.2)
       rouge (~> 3.2)
     mini_mime (1.1.2)
-    mini_portile2 (2.8.1)
+    mini_portile2 (2.8.2)
     minitest (5.18.0)
     mixlib-cli (2.1.8)
     mixlib-config (3.0.27)
@@ -310,12 +310,12 @@ GEM
     net-smtp (0.3.3)
       net-protocol
     nio4r (2.5.9)
-    nokogiri (1.14.3)
+    nokogiri (1.14.4)
       mini_portile2 (~> 2.8.0)
       racc (~> 1.4)
-    nokogiri (1.14.3-x86_64-darwin)
+    nokogiri (1.14.4-x86_64-darwin)
       racc (~> 1.4)
-    nokogiri (1.14.3-x86_64-linux)
+    nokogiri (1.14.4-x86_64-linux)
       racc (~> 1.4)
     octokit (6.1.1)
       faraday (>= 1, < 3)
@@ -450,7 +450,7 @@ GEM
       rack (>= 2.2.4, < 4)
     statsd-ruby (1.5.0)
     temple (0.10.0)
-    thor (1.2.1)
+    thor (1.2.2)
     tilt (2.0.11)
     timeout (0.3.2)
     toml (0.3.0)
@@ -471,7 +471,7 @@ GEM
     websocket-extensions (0.1.5)
     xpath (3.2.0)
       nokogiri (~> 1.8)
-    zeitwerk (2.6.7)
+    zeitwerk (2.6.8)

 PLATFORMS
   ruby
```

## Decision

RFC-156 did not account for the above behaviour. It only accounts for Dependabot PRs that change exactly one dependency. *Therefore, that is all we have automated at this stage*.

## Consequences

It might be that the auto-merge service is not utilised as fully as it could be, as not many Dependabot PRs touch only one dependency.

We can revisit this decision in future if many Dependabot PRs are not auto-merged as a result, but we'll need to consider the security implications of any change in this policy.

We deliberately only auto-merge internal dependencies as we have control over all code changes, so bypassing manual review for these is relatively low risk. If Dependabot lumps other dependency bumps into the same 'internal dependency' PR, there is a hypothetical security risk whereby a a maintainer of an external dependency could keep an eye on one of our internal dependencies and, when we release a new version, release a malicious new version of their dependency. Thus when Dependabot raises its PR, it might bump both the internal dependency and external subdependency, and the auto-merge service would happily approve and merge the PR. Our continuous deployment pipeline would then promote the malicious code all the way to production servers, provided the Smokey tests pass.
