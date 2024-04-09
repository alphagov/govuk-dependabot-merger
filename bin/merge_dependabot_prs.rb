require_relative "../lib/auto_merger"

if ARGV[0] == "--dry-run"
  AutoMerger.pretend_invoke_merge_script!
else
  AutoMerger.invoke_merge_script!
end
