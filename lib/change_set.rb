Dependency = Struct.new(:name) do
  def internal?
    Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/#{name}/owners.yaml"))
      .then { |response| YAML.safe_load response }
      .any? { |owner| owner["handle"] == "govuk" }
  rescue NoMethodError
    puts "This rubygem could not be found."
    false
  end
end

class UnexpectedCommitMessage < StandardError; end

Change = Struct.new(:dependency, :type) do
  def self.type_from_dependabot_type(dependabot_type)
    case dependabot_type
    when "version-update:semver-major"
      :major
    when "version-update:semver-minor"
      :minor
    when "version-update:semver-patch"
      :patch
    else
      # As of March 2024, these are the only options Dependabot can return
      # If they add more in the future, we will need to update this
      raise(UnexpectedCommitMessage, "Unrecognised update-type: #{dependabot_type}")
    end
  end
end

class ChangeSet
  attr_accessor :changes

  def initialize(changes = nil)
    @changes = changes.nil? ? [] : changes
  end

  def self.from_commit_message(commit_message)
    commit_message = commit_message
      .split("---", 2)[1]
      .split("...", 2)[0]

    YAML.safe_load(commit_message)
      .fetch("updated-dependencies")
      .map { |dep|
        dependency = Dependency.new(dep["dependency-name"])
        type = Change.type_from_dependabot_type(dep["update-type"])
        Change.new(dependency, type)
      }
      .then { |changes| ChangeSet.new changes }
  rescue StandardError
    raise(UnexpectedCommitMessage, "Commit message is not in the expected format")
  end
end
