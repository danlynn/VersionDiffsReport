require 'lib/app_config'


class Utils
  
  # Populate the AppConfig["environments"][env_name]["users"] hash for the 
  # specified environment as defined in environments.yml using any existing
  # users node for that environment and adding to it any mappings defined by the
  # users_plugin defined for that environment.
  #
  # @param [Hash] options hash of report properties
  # @param options [String] :env_name name of current environment
  def self.populate_users(options)
    env_name = options["env_name"]
    puts "Populating user mappings:\n  env_name: #{env_name}\n"
    env = AppConfig["environments"][env_name]
    users = env["users"] ||= Hash.new
    if env["users_plugin"]
      module_name = env["users_plugin"]["module"]
      unless Object.const_defined?(module_name) || require("lib/#{module_name.underscore}")
        raise "Unable to load module named specified in AppConfig['environments']['#{env_name}']['users_plugin']['module']: #{module_name}"
      end
      begin
        env["users_plugin"]["module"].constantize.populate_users(users, env["users_plugin"]["options"], options)
      rescue
        raise "Failed to populate users for environment '#{env_name}': #{$!}"
      end
    end
    puts "  count: #{users.size}"
  end

  # Get a reference to the vcs_plugin class for the environment specified by the
  # 'env_name' property in the 'options' hash.  The name of the vcs_plugin for
  # each environment is specified by the 'vcs_plugin' property of the specified
  # environment in the environments.yml config file.
  #
  # @param [Hash, String] options hash of report properties -or- env_name as String
  # @param options [String] :env_name name of current environment
  # @return [Class] class reference to the specified vcs_plugin class
  def self.vcs_plugin(options)
    env_name = options
    env_name = options["env_name"] if options.instance_of?(Hash)
    env = AppConfig["environments"][env_name]
    raise "Configuration Error: Specified env_name '#{env_name}' not found in environments config." unless env
    # load vcs plugin into options as module constant
    unless Object.const_defined?(env["vcs_plugin"]) || require("lib/#{env["vcs_plugin"].underscore}")
      raise "Configuration Error: Unable to load 'vcs_plugin' module named '#{env["vcs_plugin"]}' environment '#{env_name}'"
    end
    env["vcs_plugin"].constantize
  end

end