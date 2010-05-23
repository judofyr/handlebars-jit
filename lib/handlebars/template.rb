require 'handlebars/generator'
require 'handlebars/optimizer'
require 'handlebars/profile'

class Handlebars
  class Template < Mustache::Template
    attr_writer :tokens
    attr_reader :profile
    
    def initialize(*)
      super
      @profile = Profile.new
      @generator = Generator.new(:profile => @profile)
      @optimizer = Optimizer.new(:profile => @profile)
    end
    
    def tokens
      @tokens ||= super
    end
    
    def optimize
      @tokens = @optimizer.compile(tokens)
    ensure
      @profile.updated = false
    end
    
    def render(ctx)
      recompile
      render(ctx)
    end
    
    def recompile
      compiled = <<-EOF
        def render(ctx)
          if @profile.updated
            optimize
            recompile
            render(ctx)
          else
            #{compile}
          end
        end
      EOF
      
      instance_eval(compiled, __FILE__, __LINE__ - 1)
    end
    
    def compile
      @generator.compile(tokens)
    end
    
    def update(ctx, name, *args)
      @profile.updated = true
      @profile[ctx.name_stack(name)] = args
    end
    
    def append(ctx, name, *args)
      if arr = @profile[ctx.name_stack(name)]
        arr.concat(args)
      end
    end
    
    def fetch_and_profile(ctx, name)
      value, index, type = ctx.lookup(name, nil)
      update(ctx, name, index, type) if type
      value
    end
    
    ## Types
    
    def utag(ctx, name)
      fetch_and_profile(ctx, name)
    end
    
    def etag(ctx, name)
      CGI.escapeHTML(utag(ctx, name).to_s)
    end
    
    def section(ctx, name)
      case v = utag(ctx, name)
      when nil
        append(ctx, name, :object)
        ""
      when false, true
        append(ctx, name, :boolean)
        ctx.stack(name) { yield if v }
      when Proc
        append(ctx, name, :proc)
        ctx.stack(name) { v.call(yield) }
      else
        if v.is_a?(Array)
          append(ctx, name, :array)
        else
          append(ctx, name, :object)
          v = [v]
        end
        
        v.map do |h|
          ctx.stack(name, h) { yield }
        end.join
      end
    end
    
    def inverted_section(ctx, name)
      case v = fetch_and_profile(ctx, name)
      when true, false
        append(ctx, name, :boolean)
      else
        if v.is_a?(Array)
          append(ctx, name, :array)
        else
          append(ctx, name, :object)
        end
      end
      
      yield if v.nil? || v == false || v.respond_to?(:empty?) && v.empty?
    end
  end
end
