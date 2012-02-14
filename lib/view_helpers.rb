require 'lib/app_config'
require 'lib/user'


module ViewHelpers

  # Returns the HTML resulting from rendering the specified 'partial' file
  # making the 'params' arg available as a local variable for the partial
  # templates.  If the specified 'partial' isn't found then a note is output 
  # to the console and an empty string is returned for the contents of the 
  # partial.
  def self.render(partial, options)
    erb = ERB.new(@@templates[partial] ||= IO.read(partial), nil, "%<>")
    erb.result(binding)
  rescue Errno::ENOENT
    puts "    NOTE: partial not included - template file not available: #{partial}"
    ""
  end

end
