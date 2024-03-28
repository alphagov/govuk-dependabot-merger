Dependency = Struct.new(:name) do
  def internal?
    Net::HTTP.get(URI("https://rubygems.org/api/v1/gems/#{name}/owners.yaml"))
      .then { |response| YAML.safe_load response }
      .any? { |owner| owner["handle"] == "govuk" }
  end
end

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
      raise "Unrecognised update-type: #{dependabot_type}"
    end
  end
end

ChangeSet = Struct.new(:changes) do
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
    raise "Commit message is not in the expected format"
  end
end
