class Commit
  
  # @attr [String] commit_id unique commit ID
  # @attr [String] user_id repository user ID associated with commit
  # @attr [Time] time
  # @attr [Number] line_count optional number of lines changed if available
  # @attr [String] message
  attr_accessor :commit_id, :user_id, :time, :line_count, :message
  
  # @attr_reader [Array<CommitPath>] files and directories associated with commit
  attr_reader :paths

  
  def initialize(commit_id = nil, user_id = nil, time = nil, line_count = nil, message = nil, paths = [])
    @commit_id = commit_id
    @user_id = user_id
    @time = time
    @line_count = line_count
    @message = message
    @paths = paths
  end


  def <=>(commit)
    @time <=> commit.time
  end

  
  def ==(commit_path)
    @path == commit_path.path
  end
  
  
  def eql?(commit_path)
    @path.eql?(commit_path.path)
  end
  
  
  def hash
    @path.hash
  end

end
