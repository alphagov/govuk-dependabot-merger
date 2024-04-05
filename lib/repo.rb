require "yaml"
require_relative "./github_client"
require_relative "./policy_manager"
require_relative "./pull_request"

Repo = Struct.new(:name) do
  def self.all(config_file = File.join(File.dirname(__FILE__), "../config/repos_opted_in.yml"))
    YAML.safe_load_file(config_file).map { |repo_name| Repo.new(repo_name) }
  end

  def govuk_dependabot_merger_config
    GitHubClient.instance
      .contents(
        "alphagov/#{name}",
        {
          accept: "application/vnd.github.raw",
          path: ".govuk_dependabot_merger.yml",
        },
      )
      .then { |content| YAML.safe_load(content) }
  rescue Octokit::NotFound
    { "error" => "404" }
  rescue Psych::SyntaxError
    { "error" => "syntax" }
  end

  def dependabot_pull_requests
    @dependabot_pull_requests ||= GitHubClient
      .instance
      .pull_requests("alphagov/#{name}", state: :open, sort: :created)
      .select { |api_response| api_response.user.login == "dependabot[bot]" }
      .map { |api_response| PullRequest.new(api_response, PolicyManager.new(govuk_dependabot_merger_config)) }
  end

  def dependabot_pull_request(pr_number)
    PullRequest.new(GitHubClient.instance.pull_request("alphagov/#{name}", pr_number), PolicyManager.new(govuk_dependabot_merger_config))
  end
end
