require "yaml"
require_relative "./github_client"
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
      .then { |response| response.each_page.flat_map(&:to_a) }
      .select { |api_response| api_response.user.login == "dependabot[bot]" }
      .map { |api_response| PullRequest.new(api_response) }
  end

  def dependabot_pull_request(pr_number)
    PullRequest.new(GitHubClient.instance.pull_request("alphagov/#{name}", pr_number))
  end

  def dependabot_cooldown_days
    GitHubClient.instance
      .contents(
        "alphagov/#{name}",
        {
          accept: "application/vnd.github.raw",
          path: ".github/dependabot.yml",
        },
      )
      .then do |content|
        cfg = YAML.safe_load(content)

        return 0 if !cfg.key?("updates") || cfg["updates"].empty?

        return cfg["updates"].map { |update|
          update.dig("cooldown", "default-days") || 0
        }.min
      end
  rescue Octokit::NotFound
    { "error" => "404" }
  rescue Psych::SyntaxError
    { "error" => "syntax" }
  end
end
