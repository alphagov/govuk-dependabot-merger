require "ostruct"
require_relative "../../lib/pull_request"

RSpec.describe PullRequest do
  before { set_up_mock_token }

  let(:repo_name) { "foo" }
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
      statuses_url: "https://api.github.com/repos/alphagov/#{repo_name}/statuses/ee241dea8da11aff8e575941c138a7f34ddb1a51",
      head: OpenStruct.new({
        sha: "ee241dea8da11aff8e575941c138a7f34ddb1a51",
      }),
      base: OpenStruct.new({
        repo: OpenStruct.new({
          name: repo_name,
        }),
      }),
    })
  end

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

  describe ".merge!" do
    it "should output the name and PR number" do
      pr = PullRequest.new(pull_request_api_response)
      stub_request(:put, "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/merge").to_return(status: 200)

      expect { pr.merge! }.to output("Merging foo#1...\n").to_stdout
      expect(WebMock).to have_requested(:put, "https://api.github.com/repos/alphagov/#{repo_name}/pulls/1/merge")
    end
  end
end
