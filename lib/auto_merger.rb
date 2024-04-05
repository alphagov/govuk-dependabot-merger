require_relative "./bank_holidays"
require_relative "./policy_manager"
require_relative "./repo"

module AutoMerger
  def self.invoke_merge_script!
    if Date.today.is_bank_holiday?
      puts "Today is a bank holiday. Skipping auto-merge."
    else
      merge_dependabot_prs
    end
  end

  def self.merge_dependabot_prs
    Repo.all.each do |repo|
      policy_manager = PolicyManager.new(repo.govuk_dependabot_merger_config)

      if !policy_manager.remote_config_exists?
        puts "The remote .govuk_dependabot_merger.yml file is missing."
      elsif !policy_manager.valid_remote_config_syntax?
        puts "The remote .govuk_dependabot_merger.yml YAML syntax is corrupt."
      elsif !policy_manager.remote_config_api_version_supported?
        puts "The remote .govuk_dependabot_merger.yml file is using an unsupported API version."
      elsif repo.dependabot_pull_requests.count.zero?
        puts "No Dependabot PRs found for repo '#{repo.name}'."
      else
        puts "#{repo.dependabot_pull_requests.count} Dependabot PRs found for repo '#{repo.name}':"

        repo.dependabot_pull_requests.each do |pr|
          puts "  - Inspecting #{repo.name}##{pr.number}..."

          merge_dependabot_pr(pr, policy_manager, dry_run: false)
        end
      end
    end
  end

  def self.merge_dependabot_pr(pull_request, policy_manager, dry_run: true)
    if !policy_manager.is_auto_mergeable?(pull_request)
      puts "    ...auto-merging is against policy: #{policy_manager.reasons_not_to_merge(pull_request).join(' ')} Skipping."
    elsif !pull_request.is_auto_mergeable?
      puts "    ...auto-merging is allowable in theory, but bad PR: #{pull_request.reasons_not_to_merge.join(' ')} Skipping."
    elsif dry_run
      puts "    ...eligible for auto-merge! This is a dry run, so skipping."
    else
      puts "    ...approving! ✅"
      pull_request.approve!
      puts "    ...merging! 🎉"
      pull_request.merge!
    end
  end

  def self.analyse_dependabot_pr(url)
    puts "Analysing #{url}..."
    _, repo_name, pr_number = url.match(/alphagov\/(.+)\/pull\/(.+)$/).to_a
    pr = Repo.new(repo_name).dependabot_pull_request(pr_number)
    merge_dependabot_pr(pr, dry_run: true)
  end
end
