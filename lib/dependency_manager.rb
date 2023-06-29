class DependencyManager
  attr_reader :allowed_dependency_updates, :proposed_dependency_updates

  def initialize
    @allowed_dependency_updates = []
    @proposed_dependency_updates = []
  end

  def allow_dependency_update(name:, allowed_semver_bumps:)
    allowed_dependency_updates << { name:, allowed_semver_bumps: }
  end

  def propose_dependency_update(name:, previous_version:, next_version:)
    proposed_dependency_updates << { name:, previous_version:, next_version: }
  end

  def self.update_type(previous_version, next_version)
    raise SemverException unless [previous_version, next_version].all? { |str| str.match?(/^[0-9]+\.[0-9]+\.[0-9]+$/) }

    prev_major, prev_minor, prev_patch = previous_version.split(".").map(&:to_i)
    next_major, next_minor, next_patch = next_version.split(".").map(&:to_i)
    return :major if (next_major - prev_major).positive?
    return :minor if (next_minor - prev_minor).positive?
    return :patch if (next_patch - prev_patch).positive?

    :unchanged
  end

  class SemverException < StandardError; end
end
