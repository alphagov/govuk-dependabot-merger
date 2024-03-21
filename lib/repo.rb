require_relative "./github_client"
require_relative "./pull_request"

Repo = Struct.new(:name) do
  def dependabot_pull_requests
    @dependabot_pull_requests ||= GitHubClient
      .instance
      .pull_requests("alphagov/#{name}", state: :open, sort: :created)
      .select { |api_response| api_response.user.login == "dependabot[bot]" }
      .map { |api_response| PullRequest.new(api_response) }
  end

  def dependabot_pull_request(pr_number)
    PullRequest.new(GitHubClient.instance.pull_request("alphagov/#{name}", pr_number))
  end
end
