require_relative "../lib/auto_merger"

raise "Expecting exactly one argument, e.g. `ruby bin/pr_doctor.rb https://github.com/alphagov/content-data-api/pull/1996`" unless ARGV.count == 1

pr_url = ARGV.first

AutoMerger.analyse_dependabot_pr(pr_url)
