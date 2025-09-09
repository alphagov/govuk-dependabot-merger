require "ostruct"
require_relative "../../lib/pull_request"

RSpec.describe PullRequest do
  before { set_up_mock_token }

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

  let(:repo_name) { "foo" }
  let(:sha) { "ee241dea8da11aff8e575941c138a7f34ddb1a51" }
  let(:pull_request_api_response) do
    # Using OpenStruct to make each property callable as a method,
    # just like OctoKit
    OpenStruct.new(
      url: "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1",
      number: 1,
      state: "open",
      title: "First PR",
      user: OpenStruct.new(
        login: "ChrisBAshton",
        id: 5_111_927,
        type: "User",
      ),
      labels: [],
      draft: false,
      statuses_url: "https://api.github.com/repos/alphagov/#{repo_name}/statuses/#{sha}",
      head: OpenStruct.new(
        sha:,
      ),
      base: OpenStruct.new(
        repo: OpenStruct.new(
          name: repo_name,
        ),
      ),
    )
  end
  let(:head_commit_api_url) { "https://api.github.com/repos/alphagov/#{repo_name}/commits/#{sha}" }
  let(:head_commit_api_response) do
    {
      sha:,
      commit: {
        author: {
          name: "dependabot[bot]",
        },
        message: single_dependency_commit,
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

  describe "#initialize" do
    it "should take a GitHub API response shaped pull request and remote config hash" do
      PullRequest.new(pull_request_api_response)
    end
  end

  describe "#number" do
    it "should return the number of the PR" do
      pr = PullRequest.new(pull_request_api_response)
      expect(pr.number).to eq(1)
    end
  end

  describe "#is_auto_mergeable?" do
    def create_pull_request_instance
      pr = PullRequest.new(pull_request_api_response)
      allow(pr).to receive(:validate_single_commit).and_return(true)
      allow(pr).to receive(:validate_files_changed).and_return(true)
      allow(pr).to receive(:validate_dependabot_commit).and_return(true)
      pr
    end

    it "should make a call to validate_single_commit" do
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_single_commit).and_return(false)
      expect(pr).to receive(:validate_single_commit)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "PR contains more than one commit.",
      ])
    end

    it "should return false if GitHub says the commit is not signed by Dependabot" do
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_dependabot_commit).and_return(false)
      expect(pr).to receive(:validate_dependabot_commit)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "PR contains commit not signed by Dependabot.",
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

    it "should make a call to validate_ci_workflow_exists" do
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_ci_workflow_exists).and_return(false)
      expect(pr).to receive(:validate_ci_workflow_exists)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "CI workflow doesn't exist.",
      ])
    end

    it "should make a call to validate_ci_passes" do
      stub_successful_check_run
      pr = create_pull_request_instance
      allow(pr).to receive(:validate_ci_passes).and_return(false)
      expect(pr).to receive(:validate_ci_passes)
      pr.is_auto_mergeable?
      expect(pr.reasons_not_to_merge).to eq([
        "CI workflow is failing.",
      ])
    end
  end

  describe "#validate_single_commit" do
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

  describe "#validate_files_changed" do
    it "returns true if PR only changes Gemfile.lock" do
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(true)
    end

    it "returns true if PR changes Gemfile and Gemfile.lock" do
      gemfile = head_commit_api_response[:files].first.dup
      gemfile[:filename] = "Gemfile"
      head_commit_api_response[:files] << gemfile
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(true)
    end

    it "returns false if PR only changes yarn.lock" do
      head_commit_api_response[:files][0][:filename] = "yarn.lock"
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(false)
    end

    it "returns false if PR changes package.json" do
      pkg_json = head_commit_api_response[:files].first.dup
      pkg_json[:filename] = "package.json"
      head_commit_api_response[:files] << pkg_json
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(false)
    end

    it "returns false if PR changes anything else" do
      head_commit_api_response[:files][0][:filename] = "something_else.rb"
      stub_remote_commit(head_commit_api_response)

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_files_changed).to eq(false)
    end
  end

  describe "#validate_ci_workflow_exists" do
    it "returns true if there is a workflow named 'CI'" do
      stub_ci_endpoint({
        "workflow_runs": [
          { "name": "CI", "id": 1 },
        ],
      })

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_ci_workflow_exists).to eq(true)
    end

    it "returns false if there is no workflow named 'CI'" do
      stub_ci_endpoint({
        "workflow_runs": [
          { "name": "foo", "id": 2 },
        ],
      })

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_ci_workflow_exists).to eq(false)
    end

    it "should raise an exception if no workflows are returned in the response" do
      stub_ci_endpoint({ "error": "some GitHub error" })

      pr = PullRequest.new(pull_request_api_response)
      expected_output = <<~MULTILINE_OUTPUT
        Error fetching CI workflow in API response for https://api.github.com/repos/alphagov/foo/actions/runs?head_sha=#{sha}
        {"error":"some GitHub error"}
      MULTILINE_OUTPUT

      expect { pr.validate_ci_workflow_exists }.to raise_exception(
        PullRequest::UnexpectedGitHubApiResponse,
        expected_output.strip!,
      )
    end
  end

  describe "#validate_ci_passes" do
    let(:ci_workflow_id) { 1234 }
    before do
      stub_ci_endpoint({
        "workflow_runs": [
          { "name": "CI", "id": ci_workflow_id },
        ],
      })
    end

    it "returns true if all status checks in 'CI' workflow are successful or skipped'" do
      stub_runs_endpoint(ci_workflow_id, {
        "jobs": [
          { "status": "completed", "conclusion": "success" },
          { "status": "completed", "conclusion": "skipped" },
        ],
      })

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_ci_passes).to eq(true)
    end

    it "returns false if any status check is still pending" do
      stub_runs_endpoint(ci_workflow_id, {
        "jobs": [
          { "status": "in_progress" },
        ],
      })

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_ci_passes).to eq(false)
    end

    it "returns false if any status check failed" do
      stub_runs_endpoint(ci_workflow_id, {
        "jobs": [
          { "status": "completed", "conclusion": "failure" },
        ],
      })

      pr = PullRequest.new(pull_request_api_response)
      expect(pr.validate_ci_passes).to eq(false)
    end
  end

  describe "#approve!" do
    let(:approval_api_url) { "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/reviews" }

    it "should make an API call to approve the PR" do
      pr = PullRequest.new(pull_request_api_response)
      stub_request(:post, approval_api_url).with(
        body: {
          "event": "APPROVE",
          "body": "This PR has been scanned and automatically approved by [govuk-dependabot-merger](https://github.com/alphagov/govuk-dependabot-merger).\n",
        }.to_json,
      ).to_return(status: 200)

      pr.approve!
      expect(WebMock).to have_requested(:post, approval_api_url)
    end

    it "should raise an exception if request unauthorised" do
      pr = PullRequest.new(pull_request_api_response)
      stub_request(:post, approval_api_url).to_return(status: 403)

      expect { pr.approve! }.to raise_exception(PullRequest::CannotApproveException)
    end
  end

  describe "#merge!" do
    it "should make an API call to merge the PR" do
      pr = PullRequest.new(pull_request_api_response)
      stub_request(:put, "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/merge").to_return(status: 200)

      pr.merge!
      expect(WebMock).to have_requested(:put, "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/merge")
    end
  end

  def stub_remote_commit(head_commit_api_response)
    stub_request(:get, head_commit_api_url)
      .to_return(status: 200, body: head_commit_api_response.to_json, headers: { "Content-Type": "application/json" })
  end

  def stub_successful_check_run
    ci_workflow_id = 123
    stub_ci_endpoint({
      "workflow_runs": [
        { "name": "CI", "id": ci_workflow_id },
      ],
    })
    stub_runs_endpoint(ci_workflow_id, {
      "jobs": [
        { "status": "completed", "conclusion": "success" },
      ],
    })
  end

  def stub_ci_endpoint(workflow_api_response)
    stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/actions/runs?head_sha=#{sha}")
      .to_return(status: 200, body: workflow_api_response.to_json, headers: { "Content-Type": "application/json" })
  end

  def stub_runs_endpoint(ci_workflow_id, ci_workflow_api_response)
    stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/actions/runs/#{ci_workflow_id}/jobs")
      .to_return(status: 200, body: ci_workflow_api_response.to_json, headers: { "Content-Type": "application/json" })
  end
end
