require 'time'

require 'lib/app_config'
require 'lib/user'
require 'lib/commit'
require 'lib/utils'


class ReportGroup
  
  attr_reader :name, :attributes, :parent_report_group, :options
  attr_writer :commits
  attr_accessor :groups
  
  # cache of template files read from disk
  @@templates = {}


  # Construct a root ReportGroup passing in the 'commits', 'groups', and 
  # 'options'.  This root ReportGroup is mostly useful for kicking off a set of
  # reports passed in on the command line.  The 'commits' arg is mostly useful
  # for testing purposes.  If no 'commits' arg is provided then a find_by:vcs
  # query is automatically added to the new root node which will use the
  # 'env_name', 'first_commit_id', and 'last_commit_id' attributes of the 
  # report 'options' hash (configured on the command-line) to populate the 
  # commits from the version control system specified by 'env_name' option.
  # 
  # @param [Array<String>] groups list of group names representing reports to be ran consecutively
  # @param [Hash] options Hash holding report options
  # @param [Array<Commit>] commits optional initial set of commits
  # @return [ReportGroup] new ReportGroup root instance
  def self.root_report_group(groups, options, commits = nil)
    report_group = ReportGroup.new("root", options)
    report_group.groups = groups.collect do |group_name|
      ReportGroup.new(group_name, options, report_group)
    end
    if commits
      report_group.commits = commits
    else
      report_group.attributes["find_by"] = {"vcs" => {}}
    end
    report_group
  end


  # Construct new ReportGroup for the specified 'name' along with all child 
  # groups as defined in config.
  # 
  # @param [String] name name of this ReportGroup
  # @param [Hash] parent_options Hash holding report options
  # @param [ReportGroup] parent_report_group parent ReportGroup
  def initialize(name, parent_options, parent_report_group = nil)
    raise "Configuration Error: #{parent_report_group.path.join('>')} lists the group '#{name}' that has not been defined" unless AppConfig["report_groups"][name] || parent_report_group.nil?
    @name = name
    @attributes = AppConfig["report_groups"][name] || {}
    @parent_report_group = parent_report_group
    @options = parent_options.merge(@attributes["options"]) rescue parent_options
    @groups = []
    begin
      @groups = @attributes["groups"].collect do |group_name|
        if path.include?(group_name)
          raise "Configuration Error: report_groups path #{path.join('>')} attempts to loop back on itself by adding #{group_name} again"
        end
        ReportGroup.new(group_name, @options, self)
      end
    rescue NoMethodError
    end
  end


  # Get the 'find_by' hash from this report group's config.  If the 'find_by' 
  # attribute in the config references another group then use that group's 
  # 'find_by' hash of query attributes.
  # 
  # @return [Hash] hash of query attributes if found - else {}
  def find_by_hash
    return @find_by_hash if @find_by_hash
    return @find_by_hash = {} unless @attributes
    find_by = @attributes["find_by"]
    while find_by.instance_of?(String)
      unless AppConfig["report_groups"][find_by]
        raise("Configuration Error: report_groups path #{path.join('>')} specifies a group name for the find_by which forwards to a non-existent group")
      end
      find_by = AppConfig["report_groups"][find_by]["find_by"] rescue {}
    end
    @find_by_hash = find_by || {}
  end


  # Get list of commits matching find_by criteria defined for this report_group
  # in the config.  Inherits Commit list from parent report group if any then 
  # applies this group's find_by criteria to filter commits.  Note that some
  # find_by criteria ignore parent commits and generate a new Commit list (like
  # #find_by_vcs).
  #
  # Useful as field in templates
  # 
  # return [Array<Commit>] list of Commit matching find_by criteria
  def commits
    return @commits if @commits
    # perform search and memoize result
    commits_from_search = []
    commits_from_search = parent_report_group.commits if parent_report_group
    find_by_hash.each do |field, args|
      commits_from_search = self.send("find_by_#{field}".to_sym, commits_from_search, args)
    end
    @commits = commits_from_search
  end

  
  # Useful as field in templates
  # 
  # return [Array<Commit>] list of Commit - union of all child group commits
  def commits_rollup
    return commits if @groups.empty?
    @groups.inject([]) {|commits, group| commits |= group.commits_rollup}.sort!
  end


  def users
    users = AppConfig["environments"][@options["env_name"]]["users"]
    commits.collect{|commit| users[commit.user_id]}.uniq
  end
  
  
  def users_rollup
    return users if @groups.empty?
    @groups.inject([]) {|users, group| users |= group.users_rollup}.sort!
  end


  # Gets the commit paths for the commits matching this ReportGroup's find_by
  # queries filtering the paths specifically to match the find_by>commit_path
  # query of this ReportGroup and all the commit_path queries in the parent
  # hierarchy.  Note that the paths need to be filtered because the commits 
  # associated with this ReportGroup contain all the paths that were part of 
  # that commit - not just those that match the commit_path queries.
  # Works by selecting all the paths that match the current commit_path query
  # for each of the commits and unioning their results together to avoid 
  # duplicates.  Then performs the same process on THIS ReportGroup's commits 
  # for each commit_path query in the parent ReportGroup hierarchy.  The 
  # resulting paths are intersected for each parent's query.  This produces a
  # list of paths which match all the queries in the hierarchy.
  # For example, if a parent selects all files in the media directory and 
  # another parent selects just PNG files then the result will be all the paths
  # that are PNG files in the media directory.
  def commit_paths_NO_LOGGING
    queries = path_as_report_groups.collect {|group| group.find_by_hash["commit_path"]}.compact
    return commits.inject([]) {|commit_paths, commit| commit_paths | commit.paths} if queries.empty?
    queries.inject(nil) do |common_commit_paths, query|
      match = eval(query["match"]) rescue nil
      omit = eval(query["omit"]) rescue nil
      all_matching_paths = commits.inject([]) do |commit_paths, commit|
        commit_paths | commit.paths.select {|commit_path| (match.nil? || commit_path.path =~ match) && (omit.nil? || (commit_path.path =~ omit).nil?)}
      end
      (common_commit_paths ? common_commit_paths & all_matching_paths : all_matching_paths).sort!
    end
  end

  
  def commit_paths
    puts "\n\n\n=== commit_paths(): #{path.join('>')} queries:"
    queries = path_as_report_groups.collect {|group| group.find_by_hash["commit_path"]}.compact
    pp queries
    if queries.empty?
      puts "\n\n\n====== query ======\nNo commit_path query - thus select paths of all #{commits.size} commits"
      all_matching_paths = commits.inject([]) do |commit_paths, commit|
        puts "\n=== commit: #{commit.commit_id}"
        puts "all commit paths: (#{commit.paths.size})"
        pp commit.paths.collect {|path| path.path}
        result = commit_paths | commit.paths
        puts "all matching paths (#{result.size})"
        pp result.collect {|path| path.path}
        result
      end
      return all_matching_paths
    end
    queries.inject(nil) do |common_commit_paths, query|
      match = eval(query["match"]) rescue nil
      omit = eval(query["omit"]) rescue nil
      puts "\n\n\n====== query ======"
      p query
      puts "\ncommits: #{commits.collect {|commit| commit.commit_id}.join(', ')}"
      all_matching_paths = commits.inject([]) do |commit_paths, commit|
        puts "\n=== commit: #{commit.commit_id}"
        puts "all commit paths: (#{commit.paths.size})"
        pp commit.paths.collect {|path| path.path}
        result = commit_paths | commit.paths.select {|commit_path| (match.nil? || commit_path.path =~ match) && (omit.nil? || (commit_path.path =~ omit).nil?)}
        matching_paths = commit.paths.select {|commit_path| (match.nil? || commit_path.path =~ match) && (omit.nil? || (commit_path.path =~ omit).nil?)}
        puts "matching commit paths (#{matching_paths.size})"
        pp matching_paths.collect {|path| path.path}
        puts "all matching paths (#{result.size})"
        pp result.collect {|path| path.path}
        result
      end
      (common_commit_paths ? common_commit_paths & all_matching_paths : all_matching_paths).sort!
    end
  end
  

  def commit_paths_rollup
    return commit_paths if @groups.empty?
    @groups.inject([]) {|commit_paths, group| commit_paths |= group.commit_paths_rollup}.sort!
  end


  # @param [Array<Commit>] commits list - this param is ignored by find_by_vcs()
  # @param [Hash] args search criteria
  # @param args [String] :first_commit_id optional string containing regex with matching user names (not IDs)
  # @param args [String] :last_commit_id optional string containing regex with user names (not IDs) to be omitted
  def find_by_vcs(commits, args)
    env_name = (args["env_name"] rescue nil) || @options["env_name"]
    first_commit_id = (args["first_commit_id"] rescue nil) || @options["first_commit_id"]
    last_commit_id = (args["first_commit_id"] rescue nil) || @options["last_commit_id"]
    raise "Configuration Error: #{path.join('>')} specified 'find_by' 'vcs' without any 'first_commit_id' or 'last_commit_id' in the search attributes or options (command line or parent group options)" unless first_commit_id && last_commit_id
    @commits = Utils.vcs_plugin(env_name).commits(env_name, first_commit_id, last_commit_id)
  end


  # Get commits in 'commits' which satisfy the "match" and "omit" properties of
  # 'args'.  If neither "match" nor "omit" are provided then all commits are
  # returned.
  # 
  # @param [Array<Commit>] commits to be search
  # @param [Hash] args search criteria
  # @param args [String] :match string containing regex with matching user names (not IDs)
  # @param args [String] :omit string containing regex with user names (not IDs) to be omitted
  def find_by_user(commits, args)
    users = AppConfig["environments"][@options["env_name"]]["users"]
    match = eval(args["match"]) rescue nil
    omit = eval(args["omit"]) rescue nil
    commits.select do |commit|
      unless users[commit.user_id]
        puts "  Warning: commit '#{commit.commit_id}' has user_id '#{commit.user_id}' that is not found in the user mappings for environment '#{@options["env_name"]}'"
        next
      end
      (match.nil? || users[commit.user_id].name =~ match) && (omit.nil? || (users[commit.user_id].name =~ omit).nil?)
    end
  end


  # @param [Array<Commit>] commits to be search
  # @param [Hash] args search criteria
  # @param args [String] :start string containing regex with matching user names (not IDs)
  # @param args [String] :end string containing regex with user names (not IDs) to be omitted
  def find_by_time(commits, args)
    start_time = Time.parse(args["start"])
    end_time = Time.parse(args["end"])
    commits.select {|commit| commit.time >= start_time && commit.time < end_time}
  end
  
  
  # find commits which have at least one path that matches the args["match"] and
  # not args["omit"].  If no 'match' is provided then ALL paths match.  If no
  # 'omit' is provided then NO paths are omitted.
  # 
  # @param [Array<Commit>] commits to be search
  # @param [Hash] args search criteria
  # @param args [String] :start string containing regex with matching user names (not IDs)
  # @param args [String] :end string containing regex with user names (not IDs) to be omitted
  # @return [Array<Commits>] list of commits which have at least one path satisfying query
  # @raise [RuntimeException] configuration error if neither 'match' nor 'omit' attributes are provided
  def find_by_commit_path(commits, args)
    raise "Configuration Error: #{path.join('>')} specified 'find_by' 'commit_path' without any 'match' or 'omit' attributes" unless args["match"] || args["omit"]
    match = eval(args["match"]) rescue nil
    omit = eval(args["omit"]) rescue nil
    commits.select {|commit| commit.paths.any?{|commit_path| (match.nil? || commit_path.path =~ match) && (omit.nil? || (commit_path.path =~ omit).nil?)}}
  end


  # @return [Array<String>] list of ReportGroup names in parent hierarchy starting with root
  def path
    parent_report_group.path << @name rescue ["root"]
  end


  # @return [Array<ReportGroup>] list of ReportGroups in parent hierarchy starting with root
  def path_as_report_groups
    parent_report_group.path_as_report_groups << self rescue [self]
  end


  # Gets the template used to render this ReportGroup.  If a 'template' has been
  # explicitly defined in the report_groups config for this group then it will
  # be used.  Otherwise, if a file exists in the 'templates' dir with the same
  # 'name' as this ReportGroup then it will be used.  If that doesn't exist 
  # either then the default 'report_group' template will be used.  Note that 
  # ".html.erb" will be appended to any template names specified in the config.
  # 
  # @raise [RuntimeError] if template explicitly defined in config doesn't exist
  # @return [String] contents of template used by this ReportGroup
  def template
    return @template if @template
    templates_dir = Pathname("templates")
    template_path = templates_dir + Pathname(@name + ".html.erb")
    template_path = templates_dir + Pathname("report_group.html.erb") unless template_path.exists?
    if @attributes["template"] 
      template_path = templates_dir + Pathname(@attributes["template"])
      raise "Configuration Error: #{path.join('>')} specified template '#{template_path}' that does not exist"
    end
    @template = @@templates[template_path] ||= IO.read(template_path)
  end


  def render()
    
  end

end