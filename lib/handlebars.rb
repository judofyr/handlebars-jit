require 'mustache'

class Handlebars < Mustache; end

require 'handlebars/template'
require 'handlebars/context'

class Handlebars
  module Mixin
    def self.included(mod)
      mod.class_eval do
        def context
          @context ||= Handlebars::Context.new(self)
        end
        
        def self.templateify(data)
          case data
          when Handlebars::Template
            data
          when Mustache::Template
            Handlebars::Template.new(data.source)
          else
            Handlebars::Template.new(data.to_s)
          end
        end
        
        def render(data = template, local = {})
          templateify(data).render(context, local)
        end
        
        alias_method :to_html, :render
        alias_method :to_text, :render
      end
    end
  end
  
  include Mixin
end
