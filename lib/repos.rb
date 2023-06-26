require "yaml"
require_relative "./repo"

class Repos
  def self.all(config_file = File.join(File.dirname(__FILE__), "../config/repos_opted_in.yml"))
    YAML.load_file(config_file).map { |repo_name| Repo.new(repo_name) }
  end
end
