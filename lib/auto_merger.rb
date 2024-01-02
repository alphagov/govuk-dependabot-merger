require_relative "./bank_holiday_checker"
require_relative "./repo"
require_relative "./repos"

class AutoMerger
  def self.invoke_merge_script!
    if BankHolidayChecker.is_bank_holiday?
      puts "Today is a bank holiday. Skipping auto-merge."
    else
      AutoMerger.new.merge_dependabot_prs
    end
  end

  def merge_dependabot_prs
    Repos.all.each do |repo|
      repo.dependabot_pull_requests.each do |pr|
        puts "Inspecting #{repo.name}##{pr.number}..."

        if pr.is_auto_mergeable?
          puts "...approving! ✅"
          pr.approve!
          puts "...merging! 🎉"
          pr.merge!
        else
          pr.reasons_not_to_merge.each do |reason|
            puts "  Not auto-mergeable: #{reason}"
          end
          puts "...skipping."
        end
      end
    end
  end

  def self.analyse_dependabot_pr(url)
    puts "Analysing #{url}..."
    _, repo_name, pr_number = url.match(/alphagov\/(.+)\/pull\/(.+)$/).to_a
    pr = Repo.new(repo_name).dependabot_pull_request(pr_number)

    puts pr.is_auto_mergeable? ? "PR is considered auto-mergeable." : "PR is not considered auto-mergeable."
    puts 'Add `require "byebug"; byebug` inside the `is_auto_mergeable?` method to find out more.'
  end
end
