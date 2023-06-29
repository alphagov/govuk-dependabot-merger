require_relative "./bank_holiday_checker"
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
          puts "...merging! 🎉"
          pr.merge!
        else
          puts "...skipping."
        end
      end
    end
  end
end
