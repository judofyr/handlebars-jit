class Handlebars
  class Generator < Mustache::Generator
    def initialize(options = {})
      @id = 0
      @var_stack = ["local", "ctx.base", "ctx.mustache"]
    end
    
    def tmpid
      :"__handlebars_#{@id += 1}"
    end
    
    def compile!(exp)
      if exp.first == :compiled_mustache
        send("on_compiled_#{exp[1]}", exp[2..-1])
      else
        super
      end
    end
    
    ## Basic stuff
    
    def on_section(name, content)
      code, tmp = compile_under(name, content)
      ev("section(ctx, #{name.to_sym.inspect}) { #{code} }")
    end
    
    def on_inverted_section(name, content)
      code, tmp = compile_under(name, content)
      ev("inverted_section(ctx, #{name.to_sym.inspect}) { #{code} }")
    end
    
    def on_partial(name)
      ev("ctx.partial(#{name.to_sym.inspect})")
    end
    
    def on_etag(name)
      ev("etag(ctx, #{name.to_sym.inspect})")
    end
    
    def on_utag(name)
      ev("utag(ctx, #{name.to_sym.inspect})")
    end
    
    ## Compiled stuff
    
    def on_compiled_section(name, content, idx, type, sectype)
      code, tmp = compile_under(name, content, sectype)
      var = compiled_var(name, idx, type)
      
      case sectype
      when :boolean
        ev("if #{var}; #{code}; end")
      when :proc
        ev("#{var}.call(#{code})")
      when :array
        ev <<-EOF
          #{var}.map do |#{tmp}|
            begin
              ctx.push(#{name.to_sym.inspect}, #{tmp})
              #{code}
            ensure
              ctx.pop
            end
          end.join
        EOF
      when :object
        ev <<-EOF
          if #{tmp} = #{var}
            begin
              ctx.push(#{name.to_sym.inspect}, #{tmp})
              #{code}
            ensure
              ctx.pop
            end
          end
        EOF
      end
    end
    
    def on_compiled_inverted_section(name, content, idx, type, sectype)
      code, tmp = compile_under(name, content)
      var = compiled_var(name, idx, type)
      
      case sectype
      when :boolean
        ev("if !#{var}; #{code}; end")
      when :array
        ev <<-EOF
          if #{var}.empty?; #{code}; end
        EOF
      when :object
        ev <<-EOF
          v = #{var}
          if v.nil? || v.respond_to?(:empty?) && v.empty?
            #{code}
          end
        EOF
      end
    end
    
    def on_compiled_etag(name, idx, type)
      ev("CGI.escapeHTML(#{compiled_var(name, idx, type)}.to_s)")
    end
    
    def on_compiled_utag(name, idx, type)
      ev(compiled_var(name, idx, type))
    end
    
    def compiled_var(name, idx, type)
      prefix = case type
      when :string
        "[#{name.to_s.inspect}]"
      when :symbol
        "[#{name.to_sym.inspect}]"
      when :method
        ".#{name}"
      end
      
      @var_stack[idx] + prefix
    end
    
    ## Helpers
    
    def compile_under(name, code, thing = nil)
      var = tmpid()
      @var_stack.unshift(var.to_s)
      [compile(code), var]
    ensure
      @var_stack.shift
    end
  end
end
