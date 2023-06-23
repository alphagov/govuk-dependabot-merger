require_relative "./github_client"

class PullRequest
  def initialize(api_response)
    @api_response = api_response
  end

  def merge!
    puts "Merging #{@api_response.base.repo.name}##{@api_response.number}..."
    GitHubClient.instance.merge_pull_request("alphagov/#{@api_response.base.repo.name}", @api_response.number)
  end
end
