require 'lib/user'
require 'lib/utils'


module UsersPluginFile

  # Populates the provided 'users_hash' with User instances key'd by user_id.  
  # This specific plugin extracts the user_id / User mappings from the text file 
  # on the remote repository identified by options["path"].  Note that this
  # plugin currently assumes an 'url' is defined and attempts to always retrieve
  # the user mappings text file from the remote repository.  Columns are 
  # delimited by 2 or more spaces.  If any line in the file has less than 3 
  # columns then it will be skipped.
  # 
  # @param [Hash] users_hash Hash of User instances key'd by user IDs
  # @param [String] env_name name of environment in AppConfig hash
  # @param [Hash] options Hash of options defining how to obtain users for this env
  def self.populate_users(users_hash, attributes, options)
    contents = Utils.vcs_plugin(options).cat(options["env_name"], attributes["path"])
    contents.each_line do |line| 
      columns = line.chomp.split(/ {2,}/)
      users_hash[columns[0]] = User.new(columns[1],columns[2],columns[3]) if columns.size >= 3
    end
  end
  
end
