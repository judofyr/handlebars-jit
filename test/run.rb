$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib'

require 'rubygems'
require 'handlebars'
Mustache.send(:include, Handlebars::Mixin)

Dir.chdir(File.dirname(__FILE__) + '/../../mustache')
Dir.glob("test/*_test.rb", &method(:require))

# Ugly monkeypatch, please don't look!

require 'test/unit/ui/console/testrunner'

class Test::Unit::TestSuite
  def run(result, &progress_block)
    yield(STARTED, name)
    @tests.each do |test|
      test.run(result, &progress_block)
      test.run(result, &progress_block) unless test.is_a?(Test::Unit::TestSuite)
    end
    yield(FINISHED, name)
  end
end

# Store all templates, so we can reset them after each test runs.
$templates = {}

ObjectSpace.each_object(Class) do |klass|
  if klass < Mustache
    $templates[klass] = klass.instance_variable_get(:@template)
  end
end

class HandlebarRunner < Test::Unit::UI::Console::TestRunner
  def test_finished(name)
    super
    
    # Removes TestNamespace (fixes warnings)
    Object.send :remove_const, :TestNamespace if defined?(TestNamespace)
    ObjectSpace.each_object(Class) do |klass|
      if klass < Mustache
        # Reset templates
        tpl = $templates[klass] and tpl.reset
        klass.instance_variable_set(:@template, tpl)
      end
    end
  end
end

Test::Unit::AutoRunner::RUNNERS[:handlebars] = proc do |r|
  HandlebarRunner
end

ARGV << "-rh"
