Handlebars - a Mustache JIT
===========================

Synopsis
--------
    
    # There's no gem yet.
    $LOAD_PATH.unshift File.dirname(__FILE__) + '/lib'
    require 'handlebars'
    
    # Work's exactly like a Mustache:
    class Example < Handlebars
    end
    
    # Or mixin right into your Mustache class:
    class MustacheExample < Mustache
      include Handlebars::Mixin
    end
    
    # Or mixin into *all* Mustache classes:
    class Mustache
      include Handlebars::Mixin
    end

Run it as normal, but now it's *twice* as fast.


Benchmark
---------

Running the Mustache benchmark:

    $ ruby benchmarks/speed.rb 
                     user     system      total        real
    ERB          0.180000   0.000000   0.180000 (  0.183660)
    Handlebars   0.370000   0.010000   0.380000 (  0.381047)
    {{           0.790000   0.000000   0.790000 (  0.790434)
    Haml         0.790000   0.010000   0.800000 (  0.799260)


How does it work?
-----------------

Let's have a look at a Mustache template with a single section:

    {{#users}}
      * {{name}}
    {{/users}}

This can do several things depending on what `users` refer to:

* If users is an Array of Hash/Object, it loops over it
* If users ia true it simply shows the block
* If users is nil/false it doesn't show anything at all
* If users ia a Proc, it calls it with the content of the block

Because there's so many choices, it generates a lot of code:

    if v = ctx[:users]
      if v == true
        "* #{CGI.escapeHTML(ctx[:name].to_s)}\n"
      elsif v.is_a?(Proc)
        v.call("* #{CGI.escapeHTML(ctx[:name].to_s)}\n")
      else
        v = [v] unless v.is_a?(Array) # shortcut when passed non-array
        v.map do |h|
          ctx.push(h)
          r = "* #{CGI.escapeHTML(ctx[:name].to_s)}\n"
          ctx.pop
          r
        end.join
      end
    end

Notice that our block is inlined *three* times. Now image that the block
includes several other sections which also inline their blocks three times.
That's a lot of code!

Also notice the `ctx.push` and `ctx.pop`. Mustache maintains a stack of objects
where it looks for variables, and searching through this stack takes a while.


How can we improve this?
------------------------

Let's make a few assumptions:

* If a variable returns an Array, it will always return an Array
* If a variable returns a boolean, it will always return a boolean
* If a variable returns a Proc, it will always return an Proc
* If a variable returns an Object, it will always return an Object
* If a specific variable is found in position *n* in the stack once, it will
  always be available in position *n* in the stack.

By *always* I mean *in sequential renderings*, which basically means that you
always render the template with the same variables:

    # An example:
    tpl = Template.new
    tpl[:users] = User.all
    tpl.render
    
    # This follows the assumptation:
    tpl2 = Template.new
    tpl2[:users] = User.all
    tpl2.render
    
    # This also follows the assumptation:
    tpl3 = Template.new
    tpl3[:users] = []
    tpl3.render
    
    # This does not follow the assumptation:
    tpl4 = Template.new
    tpl4[:users] = false   # users was Array before, now it's a boolean
    tpl4.render

This will only be a problem if you're using the same template several places;
then you'll have to make sure to set exactly the same variables. Generally we
can assume most Mustache apps will follow assumptations.


Exploiting these assumptations
------------------------------

By exploitong these assumptations, we can compile it to:

    ctx.base[:users].map do |user|
      begin
        ctx.push(user)
        "* #{CGI.escapeHTML(user.name.to_s)}\n"
      ensure
        ctx.pop
      end
    end.join

* We know that `users` is available in the base object, so we don't need to
  search through the stack.
* We know that `users` is an Array, so we don't need to check for other things.
* We know that `name` is available in `users`, so we don't need to search     
  through the stack here either.

Of course, you don't want to write down all the types, so how can we *really*
exploit these assumptations without making the user tell the compiler anything?
It's actually quite easy. We simply compile it to this code:

    section(ctx, :users) do
      "* #{etag(ctx, :name)}\n"
    end

When this runs, it records the types of the variables and recompiles it. If
`users` is an empty Array the first we render it, Handlebars will recompile it
to:

    ctx.base[:users].map do |user|
      begin
        ctx.push(user)
        "* #{etag(ctx, :name)}\n"
      ensure
        ctx.pop
      end
    end.join
    
We can't optimize the name-variable, because we don't really know if it's 
available in `users` or not. But that's fine. Eventually we will render some 
users, and then we know that `name` is actually avaiable in `users` and it 
recompiles to:

    ctx.base[:users].map do |user|
      begin
        ctx.push(user)
        "* #{CGI.escapeHTML(user.name.to_s)}\n"
      ensure
        ctx.pop
      end
    end.join

What if User didn't have a name-attribute, but `name` was refering to a variable 
in base (`tpl[:name] = "Magnus"`)? We still need to actually render a few users 
in order to verify that `name` doesn't exist in there, but after that we can 
recompile it to:

    ctx.base[:users].map do |user|
      begin
        ctx.push(user)
        "* #{CGI.escapeHTML(ctx.base[:name].to_s)}\n"
      ensure
        ctx.pop
      end
    end.join


Cool, should I use it?
----------------------

No. Template engine performance doesn't matter. Just add a cache layer.


Okay, do you use it?
--------------------

No. I don't even use Mustache.


What can we learn from Handlebars?
----------------------------------

That it's possible to implement a JIT on top of a template engine. If you
implement a *really* slow engine (which actually is a bottleneck), you might be
able to speed it up.

