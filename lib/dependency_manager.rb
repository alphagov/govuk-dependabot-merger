require_relative "./change_set"
require_relative "./version"

class DependencyManager
  attr_reader :allowed_dependency_updates
  attr_accessor :change_set

  def initialize(remote_config = {})
    @remote_config = remote_config
    @allowed_dependency_updates = []
    @change_set = ChangeSet.new
    determine_allowed_dependencies
  end

  def remote_config_exists?
    @remote_config["error"] != "404"
  end

  def valid_remote_config?
    @remote_config["error"] != "syntax" &&
      @remote_config["api_version"] == DependabotAutoMerge::VERSION
  end

  def allow_dependency_update(name:, allowed_semver_bumps:)
    allowed_dependency_updates << { name:, allowed_semver_bumps: }
  end

  def all_proposed_dependencies_on_allowlist?
    change_set.changes.all? do |change|
      allowed_dependency_updates.map { |dep| dep[:name] }.include? change.dependency.name
    end
  end

  def all_proposed_updates_semver_allowed?
    change_set.changes.all? do |change|
      dependency = allowed_dependency_updates.find { |dep| dep[:name] == change.dependency.name }
      dependency.nil? || dependency[:allowed_semver_bumps].include?(change.type.to_s)
    end
  end

  def all_proposed_dependencies_are_internal?
    change_set.changes.all? { |change| change.dependency.internal? }
  end

private

  def determine_allowed_dependencies
    if @remote_config["auto_merge"]
      @remote_config["auto_merge"].each do |dependency|
        allow_dependency_update(
          name: dependency["dependency"],
          allowed_semver_bumps: dependency["allowed_semver_bumps"],
        )
      end
    end
  end
end
