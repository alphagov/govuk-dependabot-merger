class DependencyManager
  attr_reader :allowed_dependency_updates

  def initialize
    @allowed_dependency_updates = []
    @dependency_changes = []
  end

  def allow_dependency_update(name:, allowed_semver_bumps:)
    allowed_dependency_updates << { name:, allowed_semver_bumps: }
  end

  def proposed_dependency_updates
    @dependency_changes.map(&:name).uniq.map do |name|
      {
        name:,
        previous_version: find_previous_version(name),
        next_version: find_next_version(name),
      }
    end
  end

  def find_previous_version(dependency_name)
    @dependency_changes.find { |dep| dep.name == dependency_name && dep.previous_version }&.previous_version
  end

  def find_next_version(dependency_name)
    @dependency_changes.find { |dep| dep.name == dependency_name && dep.next_version }&.next_version
  end

  def add_dependency(name:, version:)
    @dependency_changes << OpenStruct.new(name:, next_version: version, previous_version: nil)
    validate_dependency_changes!
  end

  def remove_dependency(name:, version:)
    @dependency_changes << OpenStruct.new(name:, previous_version: version, next_version: nil)
    validate_dependency_changes!
  end

  def validate_dependency_changes!
    raise InvalidInput if @dependency_changes.map(&:name).include?(nil)

    proposed_dependency_updates.each do |update|
      raise InvalidInput if update[:previous_version].nil? && update[:next_version].nil?

      DependencyManager.validate_semver(update[:previous_version]) if update[:previous_version]
      DependencyManager.validate_semver(update[:next_version]) if update[:next_version]
    end

    @dependency_changes.map(&:name).uniq.each do |name|
      changes_with_this_name = @dependency_changes.select { |dep| dep.name == name }
      previous_versions = changes_with_this_name.map(&:previous_version).compact
      next_versions = changes_with_this_name.map(&:next_version).compact
      raise DependencyConflict if previous_versions.count > 1 || next_versions.count > 1
    end
  end

  def all_proposed_dependencies_on_allowlist?
    proposed_dependency_updates.each do |proposed_dependency|
      return false unless allowed_dependency_updates.find { |dep| dep[:name] == proposed_dependency[:name] }
    end

    true
  end

  def all_proposed_updates_semver_allowed?
    proposed_dependency_updates.each do |proposed_update|
      dependency_recognised = allowed_dependency_updates.find { |dep| dep[:name] == proposed_update[:name] }
      next unless dependency_recognised

      update_type = DependencyManager.update_type(proposed_update[:previous_version], proposed_update[:next_version])
      return false unless dependency_recognised[:allowed_semver_bumps].include?(update_type.to_s)
    end

    true
  end

  def self.update_type(previous_version, next_version)
    [previous_version, next_version].each { |version| validate_semver(version) }

    prev_major, prev_minor, prev_patch = previous_version.split(".").map(&:to_i)
    next_major, next_minor, next_patch = next_version.split(".").map(&:to_i)
    return :major if (next_major - prev_major).positive?
    return :minor if (next_minor - prev_minor).positive?
    return :patch if (next_patch - prev_patch).positive?

    :unchanged
  end

  def self.validate_semver(str)
    raise SemverException unless str.match?(/^[0-9]+\.[0-9]+\.[0-9]+$/)
  end

  class DependencyConflict < StandardError; end
  class InvalidInput < StandardError; end
  class SemverException < StandardError; end
end
