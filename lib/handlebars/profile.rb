class Handlebars
  class Profile < Hash
    attr_accessor :updated
    
    def initialize
      @updated = true
      super
    end
  end
end
