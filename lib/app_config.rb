require 'yaml'
require 'erb'
require 'pathname'


# AppConfig is a singleton Hash that automagically loads its configuration from
# 'config/config.yml' unless AppConfig.load_yaml(path/file.yml) is called.  The
# only methods are class-level [], []=, and path.  Thus AppConfig is used throughout the
# code of your project like:
#
#   require 'lib/app_config'
#   puts "AppConfig is populated from #{AppConfig.path}"
#   input = IO.read(AppConfig["input"])
#   AppConfig["output"] = generate_output(input)
#
# Note that symbols and Strings may be used interchangeably as hash keys.  The
# AppConfig class basically eliminates the need to load and initialize a global
# config hash (like $config ||= YAML.load(IO.read(path)) ) in every class that
# makes a reference to the $config global because you don't necessarily know
# which class may first attempt to use $config.
#
# You can break your config file into a series of config files to aid 
# organization.  For instance, you might have a 'config/reports' dir which
# contains a series of config files like dev.yml, test.yml, prod.yml.  These
# files contain properties that could have been placed inline in the main 
# config/config.yaml file.  But, in order to keep the config/config.yml clean,
# you can move them out into separate files and then simply place a file 
# include directive "<<file: path/*.yml" in the config/config.yml file at the
# point where you want them to be dynamically included inline into the file.
# Note that you can use regular globbing notation to specify the file(s) to be
# included.  The "<<file: path" directive may occur anywhere within a line - it
# does not need to be at the beginning of a line like a regular YAML directive.
# 
# Also note that AppConfig will evaluate any ERB '%', '<% %>', or '<%= %>' tags 
# in the config yaml file by default.  If you don't wish ERB to be evaluated 
# when the config file is read then put a %ERB_STOP_EVAL yaml directive at the 
# top of the config file.  If you want to specify that only 1 (or more) sections
# of the config file shouldn't be evaluated then you can enclose those sections
# between lines containing the %ERB_STOP_EVAL and %ERB_START_EVAL directives.
# These directives must start at the beginning of a line.  Anything following 
# the directive on the same line will be ignored.
#
# WARNING: make sure classes referred to in yaml file are already loaded (via 
# require command) or else an exception will be raised identifying the missing
# classes.
class AppConfig
  
  def self.path
    @@path rescue nil
  end
  
  def self.[](key)
    ensure_yaml_loaded
    @@hash[key.to_s]
  end

  def self.[]=(key, value)
    ensure_yaml_loaded
    @@hash[key.to_s] = value
  end
  
  def self.ensure_hash(*hash_names)
    hash = @@hash
    for hash_name in hash_names
      hash = hash[hash_name] ||= Hash.new
    end
    hash
  end
  
  # Note: any lines containing a non-commented-out <<file: path/to/file.yml 
  # will be replaced by the contents of that file prior to erb processing.
  def self.load_yaml(path, require_path_exist = true)
    raise "Could not load '#{path}' into AppConfig" unless !require_path_exist || File.exist?(path)
    @@path = path
    # load file into 'merged_contents' inserting any files specified in <<file: directives
    merged_contents = ""
    Pathname(path).each_line do |line|
      merged_contents << (!(line =~ /\s*#\s*<<file:\s+.*/) && line =~ /\s*<<file:\s+(.*)/ ? include_yaml($1) : line)
    end
    # process any ERB found in 'merged_contents' observing %ERB_START_EVAL and %ERB_STOP_EVAL directives
    evaled_contents = ""
    temp_erb_contents = ""
    erb_eval_mode = true
    merged_contents.each_line do |line|
      if line =~ /^%ERB_START_EVAL/
      	erb_eval_mode = true
      elsif line =~ /^%ERB_STOP_EVAL/
        if erb_eval_mode
          evaled_contents += ERB.new(temp_erb_contents, nil, "%<>").result(binding)
          temp_erb_contents = ""
        end
      	erb_eval_mode = false
      else
        if erb_eval_mode
          temp_erb_contents += line
        else
          evaled_contents += line
        end
      end
    end
    unless temp_erb_contents.empty?
      evaled_contents += ERB.new(temp_erb_contents, nil, "%<>").result(binding)
    end
    # parse 'evaled_contents' as YAML into the '@@hash' Hash
    @@hash = YAML.load(evaled_contents)
    missing_classes = @@hash.inspect.scan(/\#<YAML::Object:0x[A-Za-z0-9]{8,} .*?@class="(.*?)"/).uniq!.join(', ') rescue nil
    raise "WARNING: AppConfig loaded YAML containing classes which havn't been loaded yet: #{missing_classes}" if missing_classes
  end
  
  # To be used within config/config.yml to include the contents other yaml 
  # files.  Useful for extracting authentication info into an external file 
  # so that config/config.yml can be shared between team members.  Note that 
  # 'path' is normally relative to config/config.yml - but may be absolute   
  # path.  Also, the path may be globbed like "env/*.yml" or "**/*.yml".
  def self.include_yaml(path)
    include_str = ""
    pathnames = Pathname.glob(Pathname(@@path).dirname + path)
    pathnames = Pathname.glob(path) if pathnames.empty?
    for pathname in pathnames
      include_str << File.read(pathname) + "\n"
    end
    puts "WARNING: #{path} could NOT be found to be included into #{@@path}." if pathnames.empty?
    include_str
  end
  
  def self.ensure_yaml_loaded
    self.load_yaml("config/config.yml", false) unless defined?(@@hash)
  end
  
end