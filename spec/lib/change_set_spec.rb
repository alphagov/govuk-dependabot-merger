require_relative "../../lib/change_set"

RSpec.describe Dependency do
  describe "#internal?" do
    it "returns true if the dependency is owned by govuk" do
      stub_request(:get, "https://rubygems.org/api/v1/gems/foo/owners.yaml")
        .to_return(
          body: <<~BODY,
            - id: 59597
              handle: govuk
          BODY
        )

      expect(Dependency.new("foo").internal?).to eq(true)
    end

    it "returns false if the dependency is not owned by govuk" do
      stub_request(:get, "https://rubygems.org/api/v1/gems/foo/owners.yaml")
        .to_return(
          body: <<~BODY,
            - id: 123
              handle: some-malicious-actor
          BODY
        )

      expect(Dependency.new("foo").internal?).to eq(false)
    end
  end
end

RSpec.describe Change do
  describe ".type_from_dependabot_type" do
    it "converts a dependabot update-type into a symbol" do
      expect(Change.type_from_dependabot_type("version-update:semver-major")).to eq(:major)
      expect(Change.type_from_dependabot_type("version-update:semver-minor")).to eq(:minor)
      expect(Change.type_from_dependabot_type("version-update:semver-patch")).to eq(:patch)
      expect { Change.type_from_dependabot_type("foo") }.to raise_error(RuntimeError, "Unrecognised update-type: foo")
    end
  end
end

RSpec.describe ChangeSet do
  def single_dependency_commit
    <<~TEXT
      Bump govuk_publishing_components from 35.7.0 to 35.8.0

      Bumps [govuk_publishing_components](https://github.com/alphagov/govuk_publishing_components) from 35.7.0 to 35.8.0.
      - [Changelog](https://github.com/alphagov/govuk_publishing_components/blob/main/CHANGELOG.md)
      - [Commits](alphagov/govuk_publishing_components@v35.7.0...v35.8.0)

      ---
      updated-dependencies:
      - dependency-name: govuk_publishing_components
        dependency-type: direct:production
        update-type: version-update:semver-minor
      ...

      Signed-off-by: dependabot[bot] <support@github.com>
    TEXT
  end

  def multiple_dependencies_commit
    <<~TEXT
      Bump rack, rails and govuk_sidekiq

      Bumps [rack](https://github.com/rack/rack), [rails](https://github.com/rails/rails) and [govuk_sidekiq](https://github.com/alphagov/govuk_sidekiq). These dependencies needed to be updated together.

      Updates `rack` from 1.0.0 to 1.1.0
      - [Release notes](https://github.com/rack/rack/releases)
      - [Changelog](https://github.com/rack/rack/blob/main/CHANGELOG.md)
      - [Commits](rack/rack@v1.0.0...v1.1.0)

      Updates `rails` from 7.0.8 to 7.1.1
      - [Release notes](https://github.com/rails/rails/releases)
      - [Commits](rails/rails@v7.0.8...v7.1.1)

      Updates `govuk_sidekiq` from 5.7.0 to 5.8.0
      - [Changelog](https://github.com/alphagov/govuk_sidekiq/blob/main/CHANGELOG.md)
      - [Commits](alphagov/govuk_sidekiq@v5.7.0...v5.8.0)

      ---
      updated-dependencies:
      - dependency-name: rack
        dependency-type: direct:development
        update-type: version-update:semver-minor
      - dependency-name: rails
        dependency-type: direct:production
        update-type: version-update:semver-minor
      - dependency-name: govuk_sidekiq
        dependency-type: direct:production
        update-type: version-update:semver-minor
      ...

      Signed-off-by: dependabot[bot] <support@github.com>
    TEXT
  end

  describe ".from_commit_message" do
    it "parses the commit message to discover the changed dependencies" do
      change_set = ChangeSet.from_commit_message single_dependency_commit
      expect(change_set.changes).to eq([
        Change.new(Dependency.new("govuk_publishing_components"), :minor),
      ])
    end

    it "supports commits that change more than one dependency" do
      change_set = ChangeSet.from_commit_message multiple_dependencies_commit
      expect(change_set.changes).to eq([
        Change.new(Dependency.new("rack"), :minor),
        Change.new(Dependency.new("rails"), :minor),
        Change.new(Dependency.new("govuk_sidekiq"), :minor),
      ])
    end

    it "raises an error if the commit message is not in the expected format" do
      expect {
        ChangeSet.from_commit_message("Hello world!")
      }.to raise_error(RuntimeError, "Commit message is not in the expected format")

      expect {
        ChangeSet.from_commit_message("foo\n---\nsyntax: error:\n...\nbar")
      }.to raise_error(RuntimeError, "Commit message is not in the expected format")
    end
  end
end
