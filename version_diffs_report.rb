#!/usr/bin/env ruby


# External dependencies:
#   + Ruby/JRuby
#   + command-line subversion client
#     + Windows/DOS: http://www.collab.net/downloads/subversion/
#       Look for "CollabNet Subversion Command-Line Client" download
#     + OSX: built-in


require 'rubygems'
unless require 'active_support/core_ext' # for inflections
  raise "Config error: active_support not found! Try installing activesupport gem or rails gem."
end

require 'optparse'
require 'yaml'

require 'lib/app_config'
require 'lib/commit'
require 'lib/user'
require 'lib/utils'


SCRIPT_VERSION = "0.2.1"


module VersionDiffsReport
  
  # parse command line options
  #
  # @param [Array<String>] argv actual command line options (ARGV)
  # @return [Hash] parsed command line options
  def parse_command_line_options(argv)
    argv = ["-?"] if argv.size == 0
    options = {}
    opts = OptionParser.new
    opts.banner = <<-EOS
  Usage: 
      version_diffs_report.rb environment_name
      version_diffs_report.rb environment_name -f 3600 -l 3627
      version_diffs_report.rb environment_name -c config/config_test.yml
    EOS
    opts.separator <<-EOS
  
  Description:
      Generates a report showing the commits to a repository between 2 
      commit IDs.  The report is broken down by groups identified in the 
      config/config.yml file such as by directories, files, commits, EARs, 
      etc.  The data for the reports are pulled from the repository 
      identified by the 'environment_name' param passed on the command line.
      The commit range may be specified by providing first and last commit 
      IDs on the command line with the -f and -l options.  If no commit IDs
      are specified then the repository is examined to determine what the 
      latest commit ID is.  If that matches the last (-l) commit ID from the
      previous run then the commit range from the last run of the report is
      re-used.  Otherwise, if they don't match then the first commit ID 
      is assigned the value of the last commit ID from the previous run and
      the new last commit ID becomes the lattest commit in the repository.
      Thus, you can simply run the repot at repeated intervals without
      specifying any commit range in order to provide ongoing reports of 
      the changes since the last run.  The commit ranges are remembered on
      a per environment basis.
  
  Specific options
    EOS
    opts.on('-f', '--first commit_id',
        "first commit ID to include in report range"
    ) do |commit_id|
      options["first_commit_id"] = commit_id
    end
    opts.on('-l', '--last commit_id',
          "last commit ID to include in report range"
    ) do |commit_id|
      options["last_commit_id"] = commit_id
    end
    opts.on('-c', '--config file',
            "load a different base config file besides 'config/config.yml'"
    ) do |file|
      AppConfig.load_yaml(file)
    end
    opts.separator ""
    opts.separator "Common options:"
    opts.on_tail("-?", "-h", "--help", "Show this message") {puts opts; exit 0}
    opts.on_tail("-v", "--version", "Show version") {puts "#{__FILE__} #{SCRIPT_VERSION}"; exit 0}
    # parse options
    opts.parse!(argv)
    options
  end
  
  
  # Determine the first and last commit IDs to be used for the current report and
  # environment.  Place these IDs into the current report 'options' and also 
  # return them.  If no first or last commit IDs were passed in the command line
  # options then re-use the persisted first and last IDs from the previous report
  # for the current environment.  If the latest commit ID in the workspace/repo
  # is newer than the persisted IDs from the last run then shift the commit ID
  # range forward such that the previous last_commit_id is not the new 
  # first_commit_id and the new last_commit_id is the current latest_commit_id.
  # If both first and last commit IDs are provided in the command line options
  # then use them.  If only the first commit ID is provided then use the latest
  # commit ID in the workspace/repo for the last commit ID.
  #
  # @param [Hash] cmd_options command line options
  # @param cmd_options [String] :first_commit_id
  # @param cmd_options [String] :last_commit_id
  # @param [Hash] options hash of report properties
  # @param options [String] :env_name name of current environment
  # @param options [Module] :vcs_plugin module reference to vcs plugin
  # @param options [String] :first_commit_id start of report range
  # @param options [String] :last_commit_id end of report range
  # @return [Array<first_commit_id, last_commit_id>]
  def determine_report_range(cmd_options, options)
    puts "\nDetermining commit range to use for current set of reports:"
    env_name = options["env_name"]
    latest_commit_id = options["vcs_plugin"].latest_commit_id(env_name)
    persisted_env = AppConfig.ensure_hash("persistence", "environments", env_name)
    options["first_commit_id"] = cmd_options["first_commit_id"] || persisted_env["first_commit_id"]
    options["last_commit_id"] = cmd_options["last_commit_id"] || persisted_env["last_commit_id"] || latest_commit_id
    puts "\n  Range of previous report:\n    env_name: #{env_name}\n    first: #{persisted_env["first_commit_id"]}\n    last: #{persisted_env["last_commit_id"]}\n"
    unless cmd_options["first_commit_id"] || cmd_options["last_commit_id"]
      if latest_commit_id != persisted_env["last_commit_id"]
        options["first_commit_id"] = persisted_env["last_commit_id"]
        options["last_commit_id"] = latest_commit_id
      end
    end
    raise "Unable to determine first and last commit ID because of no env history. Please use -f and -l options." unless options["first_commit_id"] && options["last_commit_id"]
    [options["first_commit_id"], options["last_commit_id"]]
  end
  
  
  # save first and last commit IDs into local_persistence.yml for the current env
  # for the next time report is ran for this env
  #
  # @param [Hash] options hash of report properties
  # @param options [String] :env_name name of current environment
  # @param options [String] :first_commit_id start of report range
  # @param options [String] :last_commit_id end of report range
  def save_local_persistence(options)
    puts "\nSaving local_persistence.yml"
    persisted_env = AppConfig.ensure_hash('persistence', 'environments', options["env_name"])
    persisted_env["first_commit_id"] = options["first_commit_id"]
    persisted_env["last_commit_id"] = options["last_commit_id"]
    File.open("config/local_persistence.yml", "w") {|f| f.write(YAML.dump({"persistence" => AppConfig["persistence"]}).sub!("--- \n", ""))}
  end
  
  
  def generate_reports(commits, options)
    puts "\nGenerating reports:"
    
    for commit in commits
      puts "\n#{commit.commit_id} -- #{commit.message}\n"
      for path in commit.paths
        puts "  #{path.attributes["action"]} #{path.path}"
      end
    end
  end
  
  
  begin
    options = Hash.new
    
    # get options and config for current report run
    env_name = ARGV[0]
    raise "No environment name passed as first param" unless env_name
    raise "Environment name passed as first param does not exist in config/environments.yml!" unless AppConfig["environments"][env_name]
    cmd_options = parse_command_line_options(ARGV)
    options["env_name"] = env_name
    env = AppConfig["environments"][env_name]
    
    # ensure that users Hash is populated for all environments
    Utils.populate_users(options)
    
    # determine report range
    first_commit_id, last_commit_id = determine_report_range(cmd_options, options)
  
    # gather data for report
    puts "\nGathering commits for reports:\n  env_name: #{env_name}\n  first: #{first_commit_id}\n  last: #{last_commit_id}\n\n"
    commits = Utils.vcs_plugin(options).commits(env_name, first_commit_id, last_commit_id)
    
    # generate reports
    generate_reports(commits, options)
    
    save_local_persistence(options)
    puts "\nScript complete"
    
    puts "AppConfig['report_groups']['prod_support_team']:"
    require 'pp'
    pp AppConfig['report_groups']['prod_support_team']
  end

end
