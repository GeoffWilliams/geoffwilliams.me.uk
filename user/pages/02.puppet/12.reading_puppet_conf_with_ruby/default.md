# Reading puppet.conf with ruby
Sometimes your writing a bit of ruby code to do some mad puppet stuff and realise that do things _properly_ your going to have to read a value from `puppet.conf`... but how do you do that?

## Inside a Puppet component
If your adding code to an existing Puppet component, a quick `grep` on the source code will show you calls like:
```ruby
Puppet.settings[:masterport]
```
So you can pretty much just adapt the above symbol to be the value your looking for and your in business.

## In your own code
Lets say your writing your own ruby script and want to run with the above example.  We could try something like this:
```ruby
require 'puppet'
puts Puppet.settings[:server]
```

Running this code with `ruby` gives the result `puppet`... but wait a minute, in my `puppet.conf` file the server line is:
```
server = pe-puppet.localdomain
```

So what is going on?  Well if puppet doesn't load a config file it will attempt to use it's own default values and these are found in `defaults.rb` (use the `find` command to locate this file on your own system).

Inside this file, I see the line:
```ruby
:server => {
  :default => "puppet",
...
```

Which explains where the default value came from.

### Fixing the code
So how do we fix this?  I've fair idea how to approach this one, we'd just need to tell the Puppet class where to find its config file somehow and then all the values should be available.

The only problem with doing this is that there is no:
* documentation
* expectation of stability

Sure I could probably figure it out eventually by staring at the source code but its a lot of effort for very little gain.

### Workaround
There's a really easy way of printing values in puppet:  the trusty `config` face that you can invoke with the command `puppet config print` will do the job quickly and easily.  As a bonus, it also lets you easily read data from any section you like - something which isn't easy with the native ruby code.

Our fixed code now looks like this:
```ruby
puts %x{puppet config print server}
```

And running it gives the correct answer
```shell
[root@localhost ~]# /opt/puppetlabs/puppet/bin/ruby test.rb
pe-puppet.localdomain
```

### Gotcha
The above code will work fine if your running as root but what if you happen to be another user?

Lets try running that script again:
```shell
[geoff@localhost ~]$ /opt/puppetlabs/puppet/bin/ruby test.rb
puppet
```

Oh noes!  We're back to the settings from `defaults.rb` again - but why?

A bit of googling leads to [https://projects.puppetlabs.com/issues/16637](https://projects.puppetlabs.com/issues/16637) -- in a nutshell, when running as `root` puppet will default to reading its config file from `/etc/puppetlabs/puppet.conf` (if using PE or AIO) and for all other users will read from `~/.puppet`!  So the command above was looking for a non-existant config file in a hidden directory, no wonder it didn't work.

This can be fixed by adding the `--confdir` flag and our command now looks like this:
```ruby
puts %x{puppet config print --confdir /etc/puppetlabs/puppet server}
```

## Config file sections
There are four config file sections available:
* `main`
* `master`
* `agent`
* `user`
If your doing _normal_ ruby coding your typically stuck with your pick of whatever section puppet things it should be in, e.g., if inside the `pupet agent` face you would get a merge of the `main` and `agent` sections.

With the `puppet config` face your free of this restriction and there's a built-in `--section` argument you can use to do lookups wherever you like, eg:
```ruby
puts %x{puppet config print --confdir /etc/puppetlabs/puppet http_proxy_host --section user}
```

Would print out the value for `http_proxy_host` in the `[user]` section... Cool!

## Other scripting languages
Since `puppet config` is just a shell command, you can use it in any script you like.  It's pretty common to see people capturing output and assigning it to shell variables in BASH like this:
```shell
FOO=$(puppet config print server)
```

# Summary
That should be all you need to start looking up your variables from `puppet.conf` instead of hardcoding them all over the place.

Don't forget there's a complete configuration file reference over at [https://docs.puppetlabs.com/references/latest/configuration.html](https://docs.puppetlabs.com/references/latest/configuration.html)
