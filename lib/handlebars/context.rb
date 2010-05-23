class Handlebars
  class Context
    attr_reader :base, :mustache
    
    def initialize(mustache)
      @mustache = mustache
      
      @base = {}
      @stack = [@base, @mustache]
      @name_stack = []
    end
    
    def name_stack(name)
      [name, *@name_stack]
    end
    
    def push(name, obj)
      @name_stack.unshift(name)
      @stack.unshift(obj)
    end
    
    def pop
      @name_stack.shift
      @stack.shift
    end
    
    def stack(name, obj = nil)
      push(name, obj)
      yield
    ensure
      pop
    end
    
    def [](key)
      fetch(key, nil)
    end
    
    def []=(key, value)
      @base[key] = value
    end
    
    def mustache_in_stack
      @stack.detect { |frame| frame.is_a?(Mustache) }
    end
    
    def partial(name)
      # Look for the first Mustache in the stack.
      mustache = mustache_in_stack

      # Call its `partial` method and render the result.
      mustache.render(mustache.partial(name), self)
    end
    
    def lookup(name, default = :__raise)
      @stack.each_with_index do |frame, index|
        # Prevent infinite recursion.
        next if frame == self or frame.nil?

        # Is this frame a hash?
        hash = frame.respond_to?(:has_key?)
        
        if hash && frame.has_key?(name.to_sym)
          return frame[name], index, :symbol
        elsif hash && frame.has_key?(name.to_s)
          return frame[name.to_s], index, :string
        elsif !hash && frame.respond_to?(name)
          return frame.__send__(name), index, :method
        end
      end

      if default == :__raise || mustache_in_stack.raise_on_context_miss?
        raise Mustache::ContextMiss.new("Can't find #{name} in #{@stack.inspect}")
      else
        default
      end
    end
    
    def fetch(name, default = :__raise)
      value, index, type = lookup(name, default)
      value
    end
  end
end
