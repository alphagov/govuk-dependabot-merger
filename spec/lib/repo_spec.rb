require_relative "../../lib/repo"

RSpec.describe Repo do
  before { set_up_mock_token }

  describe ".name" do
    it "should return the name of the repo" do
      repo_name = "foo"
      repo = Repo.new(repo_name)
      expect(repo.name).to eq(repo_name)
    end
  end

  describe ".dependabot_pull_requests" do
    it "should return an array of PullRequest objects" do
      repo_name = "foo"
      pull_request_api_response = {
        foo: "bar",
      }

      stub_request(:get, "https://api.github.com/repos/alphagov/#{repo_name}/pulls?sort=created&state=open")
        .to_return(status: 200, body: [pull_request_api_response, pull_request_api_response])

      repo = Repo.new(repo_name)
      expect(repo.dependabot_pull_requests).to all be_a_kind_of(PullRequest)
      expect(repo.dependabot_pull_requests.count).to eq(2)
    end
  end
end
