require "httparty"

Update = Struct.new(:previous_version, :next_version) do
  def type
    [previous_version, next_version].each { |version| DependencyManager.validate_semver(version) }

    prev_major, prev_minor, prev_patch = previous_version.split(".").map(&:to_i)
    next_major, next_minor, next_patch = next_version.split(".").map(&:to_i)
    return :major if (next_major - prev_major).positive?
    return :minor if (next_minor - prev_minor).positive?
    return :patch if (next_patch - prev_patch).positive?

    :unchanged
  end
end

class DependencyManager
  attr_reader :allowed_dependency_updates, :proposed_dependency_updates

  def initialize
    @allowed_dependency_updates = []
    @proposed_dependency_updates = Hash.new { |h, v| h[v] = Update.new }
  end

  def allow_dependency_update(name:, allowed_semver_bumps:)
    allowed_dependency_updates << { name:, allowed_semver_bumps: }
  end

  def add_dependency(name:, version:)
    raise DependencyConflict unless proposed_dependency_updates[name].next_version.nil?

    proposed_dependency_updates[name].next_version = version
    validate_dependency_changes!
  end

  def remove_dependency(name:, version:)
    raise DependencyConflict unless proposed_dependency_updates[name].previous_version.nil?

    proposed_dependency_updates[name].previous_version = version
    validate_dependency_changes!
  end

  def validate_dependency_changes!
    raise InvalidInput if proposed_dependency_updates.keys.include?(nil)

    proposed_dependency_updates.each_value do |update|
      raise InvalidInput if update.previous_version.nil? && update.next_version.nil?

      DependencyManager.validate_semver(update.previous_version) if update.previous_version
      DependencyManager.validate_semver(update.next_version) if update.next_version
    end
  end

  def all_proposed_dependencies_on_allowlist?
    proposed_dependency_updates.each_key do |name|
      return false unless allowed_dependency_updates.find { |dep| dep[:name] == name }
    end

    true
  end

  def all_proposed_updates_semver_allowed?
    proposed_dependency_updates.each do |name, update|
      dependency_recognised = allowed_dependency_updates.find { |dep| dep[:name] == name }
      next unless dependency_recognised

      return false unless dependency_recognised[:allowed_semver_bumps].include?(update.type.to_s)
    end

    true
  end

  def all_proposed_dependencies_are_internal?
    proposed_dependency_updates.each_key do |name|
      uri = "https://rubygems.org/api/v1/gems/#{name}/owners.yaml"
      gem_owners = YAML.safe_load(HTTParty.get(uri))
      return false unless gem_owners.map { |owner| owner["handle"] }.include?("govuk")
    end

    true
  end

  def self.validate_semver(str)
    raise SemverException unless str.match?(/^[0-9]+\.[0-9]+\.[0-9]+$/)
  end

  class DependencyConflict < StandardError; end
  class InvalidInput < StandardError; end
  class SemverException < StandardError; end
end
