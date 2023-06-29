require "ostruct"
require_relative "../../lib/pull_request"

RSpec.describe PullRequest do
  before { set_up_mock_token }

  let(:repo_name) { "foo" }
  let(:sha) { "ee241dea8da11aff8e575941c138a7f34ddb1a51" }
  let(:pull_request_api_response) do
    # Using OpenStruct to make each property callable as a method,
    # just like OctoKit
    OpenStruct.new({
      url: "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1",
      number: 1,
      state: "open",
      title: "First PR",
      user: OpenStruct.new({
        login: "ChrisBAshton",
        id: 5_111_927,
        type: "User",
      }),
      labels: [],
      draft: false,
      statuses_url: "https://api.github.com/repos/alphagov/#{repo_name}/statuses/#{sha}",
      head: OpenStruct.new({
        sha:,
      }),
      base: OpenStruct.new({
        repo: OpenStruct.new({
          name: repo_name,
        }),
      }),
    })
  end
  let(:head_commit_api_url) { "https://api.github.com/repos/alphagov/#{repo_name}/commits/#{sha}" }
  let(:head_commit_api_response) do
    {
      sha:,
      commit: {
        author: {
          name: "dependabot[bot]",
        },
      },
      author: {
        login: "dependabot[bot]",
      },
      stats: {
        total: 2,
        additions: 1,
        deletions: 1,
      },
      files: [
        {
          sha: "def456",
          filename: "Gemfile.lock",
          status: "modified",
          patch: <<~GEMFILE_LOCK_DIFF,
            govuk_personalisation (0.13.0)
                    plek (>= 1.9.0)
                    rails (>= 6, < 8)
            -    govuk_publishing_components (35.7.0)
            +    govuk_publishing_components (35.8.0)
                    govuk_app_config
                    govuk_personalisation (>= 0.7.0)
                    kramdown
          GEMFILE_LOCK_DIFF
        },
      ],
    }
  end
  let(:external_config_file_api_url) { "https://api.github.com/repos/alphagov/#{repo_name}/contents/.govuk_automerge_config.yml" }

  describe ".initialize" do
    it "should take a GitHub API response shaped pull request" do
      PullRequest.new(pull_request_api_response)
    end
  end

  describe ".number" do
    it "should return the number of the PR" do
      pr = PullRequest.new(pull_request_api_response)
      expect(pr.number).to eq(1)
    end
  end

  describe ".is_auto_mergeable?" do
    it "should make a call to validate_single_commit" do
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_single_commit).and_return(false)
      expect(pr).to receive(:validate_single_commit)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "PR contains more than one commit.",
      ])
    end

    it "should make a call to validate_files_changed" do
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_files_changed).and_return(false)
      expect(pr).to receive(:validate_files_changed)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "PR changes files that should not be changed.",
      ])
    end

    it "should make a call to validate_external_config_file" do
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_external_config_file).and_return(false)
      expect(pr).to receive(:validate_external_config_file)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "The remote .govuk_automerge_config.yml file is missing or in the wrong format.",
      ])
    end

    def create_pull_request_instance
      pr = PullRequest.new(pull_request_api_response)
      allow(pr).to receive(:validate_single_commit).and_return(true)
      allow(pr).to receive(:validate_files_changed).and_return(true)
      allow(pr).to receive(:validate_external_config_file).and_return(true)
      pr
    end
  end

  describe ".validate_single_commit" do
    let(:commit_response) do
      {
        sha: "abc123",
        commit: {
          author: {
            name: "dependabot[bot]",
          },
        },
      }
    end
    let(:commit_api_url) { "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/commits" }

    it "return true if PR contains a single commit" do
      stub_request(:get, commit_api_url)
        .to_return(status: 200, body: [commit_response])

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_single_commit).to eq(true)
    end

    it "return false if PR contains more than one commit" do
      stub_request(:get, commit_api_url)
        .to_return(status: 200, body: [commit_response, commit_response])

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_single_commit).to eq(false)
    end
  end

  describe ".validate_files_changed" do
    it "returns true if PR only changes Gemfile.lock" do
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(true)
    end

    it "returns false if PR changes anything else" do
      head_commit_api_response[:files][0][:filename] = "something_else.rb"
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(false)
    end
  end

  describe ".validate_external_config_file" do
    it "returns false if there is no automerge config file in the repo" do
      stub_request(:get, external_config_file_api_url)
        .to_return(status: 404)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_external_config_file).to eq(false)
    end

    it "returns false if the automerge config file is on a different version" do
      contents_api_response = <<~EXTERNAL_CONFIG_YAML
        dependabot_auto_merge_config:
          api_version: -1
          foo: bar
      EXTERNAL_CONFIG_YAML

      stub_request(:get, external_config_file_api_url)
        .to_return(status: 200, body: contents_api_response.to_json, headers: { "Content-Type": "application/json" })

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_external_config_file).to eq(false)
    end

    it "returns true if the automerge config file exists and contains nothing unexpected" do
      stub_remote_allowlist

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_external_config_file).to eq(true)
    end
  end

  describe ".merge!" do
    it "should output the name and PR number" do
      pr = PullRequest.new(pull_request_api_response)
      stub_request(:put, "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/merge").to_return(status: 200)

      expect { pr.merge! }.to output("Merging foo#1...\n").to_stdout
      expect(WebMock).to have_requested(:put, "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/merge")
    end
  end

  def stub_remote_commit(head_commit_api_response)
    stub_request(:get, head_commit_api_url)
      .to_return(status: 200, body: head_commit_api_response.to_json, headers: { "Content-Type": "application/json" })
  end
end

def stub_remote_allowlist
  contents_api_response = <<~EXTERNAL_CONFIG_YAML
    dependabot_auto_merge_config:
      api_version: 0 # still feeling out the API. Experimental. This file is subject to change.
      auto_merge:
        - dependency: govuk_publishing_components
          allowed_semver_bumps:
            - patch
            - minor
        - dependency: rubocop-govuk
          allowed_semver_bumps:
            - patch
            - minor
  EXTERNAL_CONFIG_YAML

  stub_request(:get, external_config_file_api_url)
    .to_return(status: 200, body: contents_api_response.to_json, headers: { "Content-Type": "application/json" })
end
