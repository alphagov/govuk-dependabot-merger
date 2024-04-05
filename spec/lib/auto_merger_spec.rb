require "date"
require_relative "../../lib/auto_merger"

RSpec.describe AutoMerger do
  describe ".invoke_merge_script!" do
    it "should fail silently if this is a bank holiday" do
      allow(Date).to receive(:bank_holidays).and_return([Date.today])

      expect(AutoMerger).not_to receive(:merge_dependabot_prs)
      expect { AutoMerger.invoke_merge_script! }.to output("Today is a bank holiday. Skipping auto-merge.\n").to_stdout
    end
  end
end
