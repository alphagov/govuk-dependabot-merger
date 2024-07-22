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

  def self.extract_commit_info(commit_title)
    # Exclude range conditions
    return nil if commit_title.match?(/>=\s*\d+\.\d+(?:\.\d+)?\s*,\s*<\s*\d+\.\d+(?:\.\d+)?/)

    match = commit_title.match(/(?:[>=~]*\s*)(\d+\.\d+(?:\.\d+)?(?:-[\w.]+)?) to (?:[>=~]*\s*)(\d+\.\d+(?:\.\d+)?(?:-[\w.]+)?)/)

    return nil unless match

    { from_version: match[1], to_version: match[2] }
  end

  def self.determine_update_type(from_version, to_version)
    return nil unless Gem::Version.correct?(from_version) && Gem::Version.correct?(to_version)

    diff_index = Gem::Version.new(to_version).segments.zip(Gem::Version.new(from_version).segments).index { |a, b| a != b }
    return nil if diff_index.nil?

    %i[major minor patch][diff_index]
  end

  def self.update_type(commit_message)
    versions = extract_commit_info(commit_message.lines.first)
    determine_update_type(versions[:from_version], versions[:to_version])
  end
end

class ChangeSet
  attr_accessor :changes

  def initialize(changes = nil)
    @changes = changes.nil? ? [] : changes
  end

  def self.from_commit_message(commit_message)
    dependencies = commit_message
      .split("---", 2)[1]
      .split("...", 2)[0]

    YAML.safe_load(dependencies)
      .fetch("updated-dependencies")
      .map { |dep|
        dependency = Dependency.new(dep["dependency-name"])
        type = dep["update-type"].nil? ? Change.update_type(commit_message) : Change.type_from_dependabot_type(dep["update-type"])
        Change.new(dependency, type)
      }
      .then { |changes| ChangeSet.new changes }
  rescue StandardError
    raise(UnexpectedCommitMessage, "Commit message is not in the expected format")
  end
end
