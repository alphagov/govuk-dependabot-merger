require_relative "../lib/repos"

Repos.all.each do |repo|
  repo.dependabot_pull_requests.each do |pr|
    # TODO: add all the validation rules from RFC-156
    pr.merge!
  end
end
