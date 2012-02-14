class CommitPath
  
  # @attr [String] path file or dir associated with a commit
  # @attr [Hash] attributes additional information about this path which may vary between VCSs
  attr_accessor :path, :attributes

  # Create a new CommitPath
  #
  # @param [String] path file or dir associated with a commit
  # @param [Hash] attributes additional information about this path which may vary between VCSs
  def initialize(path, attributes = {})
    @path = path
    @attributes = attributes
  end

  def <=>(commit_path)
    @path.downcase <=> commit_path.path.downcase
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
