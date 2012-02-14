require 'rubygems'
unless Object.const_defined?("Nokogiri") || require('nokogiri')
  raise "Config error: nokogiri not found! Try installing nokogiri gem used for XML parsing."
end

require 'lib/app_config'
require 'lib/commit'
require 'lib/commit_path'


# Version control system (vcs) plugin for interacting with the command-line
# svn client.  Assumes that the command-line svn client is already logged-in
# so that commands like 'log' can be executed.  
# 
# All methods in this class use AppConfig to obtain repository connection info
# 
# @author danlynn
module VcsPluginSvn

  # Get the list of commits for the repo defined by 'env_name' between commit 
  # IDs 'first_commit_id' and 'last_commit_id'.  If 'end' is omitted then it 
  # defaults to the most recent commit.
  # 
  # @param [String] env_name environment name to query for commits
  # @param [String] first_commit_id starting commit ID
  # @param [String, nil] last_commit_id ending commit ID (defaults to latest_commit_id()))
  # @return [Array<Commit>] list of Commit instances
  def self.commits(env_name, first_commit_id, last_commit_id = nil)
    commits = []
    url, path, username, password = repo_config(env_name)
    last_commit_id ||= latest_commit_id(env_name)
    puts "  svn: querying for commits between #{first_commit_id} and #{last_commit_id}..."
    response = `svn log -v -r #{first_commit_id}:#{last_commit_id} --username #{username} --password #{password} --xml #{url} #{path}`
    puts "  svn: complete"
    #response = File.read("test_data/svn_log.xml")
    doc = Nokogiri::Slop(response)
    doc.log.logentry.each do |logentry|
      commit = Commit.new
      commit.commit_id = logentry["revision"]
      commit.user_id = logentry.author.content
      commit.time = Time.parse(logentry.date.content)
      commit.message = logentry.msg.content
      # TODO add paths to Commit and to paths list
      logentry.xpath(".//path").each do |path_node|
        commit.paths << CommitPath.new(path_node.content, {"kind" => path_node["kind"], "action" => path_node["action"]})
      end
      commits << commit
    end
    commits
  end
  
  
  # Get the commit ID (revision number for svn) of the currently latest commit
  #
  # @param [String] env_name environment name to query
  # @return [String] ID of the last commit to the repo
  def self.latest_commit_id(env_name)
    url, path, username, password = repo_config(env_name)
    puts "  svn: querying for latest commit ID..."
    response = `svn info --username #{username} --password #{password} --xml #{url} #{path}`
    puts "  svn: complete"
    #response = File.read("test_data/svn_get_info.xml")
    Nokogiri::Slop(response).info.entry.commit["revision"]
  end

  
  # Get latest contents of a file for the specified 'file_path' from the remote 
  # repository identified by 'env_name'.  If 'commit_id' is specified then that
  # specific version of the file's contents will be retrieved.
  # 
  # @param [String] env_name environment name to query
  # @param [String] file_path path to file relative to URL/path of repo in env config
  # @param [String] commit_id optional revision from which to retrieve file contents
  # @return [String] contents of file
  def self.cat(env_name, file_path, commit_id = nil)
    url, path, username, password = repo_config(env_name)
    puts "  svn: retrieving contents of file from '#{url}#{path}#{file_path}'..."
    response = `svn cat --username #{username} --password #{"-r "+commit_id if commit_id} #{password} #{url}#{path}#{file_path}`
    puts "  svn: complete"
    #response = File.read('test_data/WhoAmI.txt')
    response
  end

  
  private
  
  
  # Get url, path, username, password from AppConfig for the current environment
  #
  # @param [String] env_name environment name to query
  # @return [Array<String>] url, path, username, password for parallel assignment
  def self.repo_config(env_name)
    environment = AppConfig["environment"]
    url = AppConfig["environments"][env_name]["url"]
    path = AppConfig["environments"][env_name]["path"]
    username = AppConfig["environments"][env_name]["username"]
    password = AppConfig["environments"][env_name]["password"]
    [url, path, username, password]
  end
end
