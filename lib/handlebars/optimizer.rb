class Handlebars
  class Optimizer
    def initialize(options = {})
      @profile = options[:profile]
      @stack = []
    end
    
    def compile(exp)
      return exp unless exp.is_a?(Array)
      
      case exp[0]
      when :multi
        [:multi, *exp[1..-1].map { |e| compile(e) }]
      when :mustache
        name = exp[2].to_sym
        res = profiled(name)
        
        if exp[1].to_s =~ /compiled/ or !res
          exp.map { |e| compile(e) }
        else
          type = :"compiled_#{exp[1]}"
          
          if exp[3]
            @stack.unshift(name)
            rest = compile(exp[3])
            @stack.shift
          end
          
          [:mustache, type, name, rest, *res].compact
        end
      else
        exp
      end
    end
    
    def profiled(name)
      args = [name.to_sym, *@stack]
      @profile[args]
    end
  end
end
