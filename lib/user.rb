class User
  
  # @attr [String] name
  # @attr [String] email
  # @attr [String] phone
  attr_accessor :name, :email, :phone

  # @param [String] name
  # @param [String] email optional
  # @param [String] phone optional
  def initialize(name, email = nil, phone = nil)
    @name = name
    @email = email
    @phone = phone
  end

end
