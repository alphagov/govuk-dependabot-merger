require_relative "../../lib/repos"

RSpec.describe Repos do
  before { set_up_mock_token }

  describe "#all" do
    it "should return an array of Repo objects" do
      repos = Repos.all(File.join(File.dirname(__FILE__), "../config/test_repos_opted_in.yml"))
      expect(repos).to all be_a_kind_of(Repo)
      expect(repos.count).to eq(2)
    end
  end
end
