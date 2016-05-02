# Retrofitting Testing To Your Puppet Modules
Testing is great, everyone should test from day one, but... not everyone does, for one reason or another.  Fortunately, there's a really easy way to add testing to an existing module called [Puppet-Retrospec](https://github.com/nwops/puppet-retrospec).

## Why the sudden urgency?
Testing Puppet Modules is always recommended but often gets pushed to the bottom of the todo list at a lot of customer sites.  Right now, we're starting to see customers migrate away from their existing Puppet 3.x servers to PE 201x and the Puppet 4 Parser.

The Puppet 4 Parser brings some truly great new features that customers have been asking for for a long time such as:
* Strong data types
* Iteration
* Lots of syntax improvements and edge-case cleanups
There's some pretty in-depth technical writeups of the new features over at 	
[R.I.Pienaar's blog](https://www.devco.net/archives/2015/07/31/shiny-new-things-in-puppet-4.php) and also [On the Bleeding Edge of Puppet](http://puppet-on-the-edge.blogspot.com.au/).

Unfortunately, these changes come with the caveat that your Puppet Code needs to be less _sloppy_ for want of a better word.  Specifically:
* Strings must be quoted
* Octal numbers (file permissions) must be quoted
* The empty string `''` now equates to false (as in most other programming languages)

To prevent on-upgrade failures, Puppet customers are now looking for ways to prepare code for the future so that it works as expected with the new parser.

## How to prepare for PE 201x/Puppet 4 parser
One way of preparing for the future is to invest the time in getting the [Catalog Preview](https://forge.puppet.com/puppetlabs/catalog_preview) module from Puppet to inspect how entire catalogues will be built with the Puppet 4 Parser vs _Classic_ puppet.  This is great for obtaining a birds-eye view of how an upgrade would affect nodes at the catalogue level.

This is all well and good but you can make this job a lot easier by making sure that the modules your using are uplifted before this process takes place and this is the focus of this blog post.

## What is Puppet-Retrospec
[Puppet-Retrospec](https://github.com/nwops/puppet-retrospec) takes an existing module with no testing and adds [RSpec Puppet](http://rspec-puppet.com/) testing with a single command.  Pretty cool eh!

### Where should I run my tests?
*Never run your tests on the Puppet Master!*

This is not the place to go experimenting with `RubyGems` and CPU bound testing.  Be warned that changing the `RubyGems` Puppet is using can break your Puppet installation.

The best place to run your tests is a completely separate and isolated computer such as:
* Your laptop
* A VM running on your laptop (by far the best place to setup your testing)
* A VM running _in the cloud_
* A dedicated CI server

For the purposes of this blog post, I'll run the tests from a Centos 7.2 VM running on my laptop (using [Vagrant](https://www.vagrantup.com/)).

### Preparing your system
With a freshly booted minimal VM, I ran the following commands as root to install the Puppet-Retrospec software and its dependences.
```shell
yum install ruby ruby-devel git
gem install puppet-retrospec bundler facter
```

### Testcase
To demonstrate how RetroSpec works, I'll be using a made up module called `mod_foo` which has the following initial directory structure:
```
mod_foo/
`-- manifests
    `-- init.pp
```

The `init.pp` file contains a single, badly written class:
```puppet
class mod_foo($do_stuff='') {
  file { /var/foo:
    ensure => directory,
    owner  => root,
    group  => root,
    mode   => 0755,
  }

  if $do_stuff {
    service { 'foo':
      ensure => running,
      enable => true,
    }
  }
}
```

## Lets test!
With your testing VM setup, your ready to generate and run some tests.  The rest of the blog post assumes your current working directory is the Puppet Module under test.  In my case, the module is saved my VM's `/vagrant/mod_foo` directory, so that it is shared with the host computer.

### Step 1: (Try to...) Generate tests
We _try_ to generate an initial set of tests by running the command:
```shell
retrospec puppet --enable-future-parser
```

With the above `init.pp` file, running this command will result in an error:
```
Manifest file: /vagrant/mod_foo/manifests/init.pp has parser errors, please fix and re-check using                                               
 puppet parser validate /home/vagrant/mod_foo/manifests/init.pp
```

### Step 2: Fix the syntax errors
Believe it or not, this is *good* and is exactly why we are using RetroSpec in the first place!

The next step here is to find out exactly what the syntax errors are, using a the suggested command.  This will tell us exactly what the errors are:
```
bundle exec puppet parser validate /home/vagrant/mod_foo/manifests/init.pp

...

Error: Could not parse for environment production: Syntax error at 'foo' at /home/vagrant/mod_foo/manifests/init.pp:2:15
```

_If running the suggested `puppet parser validate` command fails, see the troubleshooting section for a solution._

Opening up the `init.pp` file and looking at line 2, we see:
```
file { /var/foo:
```

...Whoops!  The filename wasn't quoted.  This isn't unusual in older Puppet modules.  We can fix this by putting single `'` or double `"` quotes around values.  Lets fix this line and also have a look through the rest of the file as there are a few lines with this problem in the file.

The fixed version of `init.pp` looks like this:
```puppet
class mod_foo($do_stuff='') {
  file { '/var/foo':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  if $do_stuff {
    service { 'foo':
      ensure => running,
      enable => true,
    }
  }
}
```

Once `puppet parser validate` gives no output, the code is valid and we can try to generate the tests again.

### Step 3: Generate the tests (again...)
With our newly valid Puppet Code, we can try and generate our tests again:
```shell
retrospec puppet --enable-future-parser
```

This time, we should see a bunch of new files being generated:
```
Successfully ran hook: /root/.retrospec/repos/retrospec-puppet-templates/clone-hook

Successfully ran hook: /root/.retrospec/repos/retrospec-puppet-templates/pre-hook

 + /vagrant/mod_foo/.bundle/
 + /vagrant/mod_foo/.bundle/config
 + /vagrant/mod_foo/.fixtures.yml
 + /vagrant/mod_foo/.git/
 + /vagrant/mod_foo/.git/hooks/
 + /vagrant/mod_foo/.git/hooks/pre-commit
 + /vagrant/mod_foo/.gitignore
 + /vagrant/mod_foo/.puppet-lint.rc
 + /vagrant/mod_foo/.travis.yml
 + /vagrant/mod_foo/DEVELOPMENT.md
 + /vagrant/mod_foo/Gemfile
 + /vagrant/mod_foo/Rakefile
 + /vagrant/mod_foo/Vagrantfile
 + /vagrant/mod_foo/files/
 + /vagrant/mod_foo/files/.gitkeep
 + /vagrant/mod_foo/spec/
 + /vagrant/mod_foo/spec/acceptance/
 + /vagrant/mod_foo/spec/shared_contexts.rb
 + /vagrant/mod_foo/spec/spec_helper.rb
 + /vagrant/mod_foo/templates/
 + /vagrant/mod_foo/templates/.gitkeep
 + /vagrant/mod_foo/tests/
 + /vagrant/mod_foo/tests/.gitkeep
 + /vagrant/mod_foo/mod_foo_schema.yaml
 + /vagrant/mod_foo/metadata.json
 + /vagrant/mod_foo/spec/classes/
 + /vagrant/mod_foo/spec/classes/mod_foo_spec.rb
Successfully ran hook: /root/.retrospec/repos/retrospec-puppet-templates/post-hook
```
What's happened here is that Puppet-Retrospec has inspected the module, installed a skeleton test infrastructure and wrote tests modeling the resources in `init.pp`.  If you had other Puppet Code in the module it would attempt to generate tests for that too... Cool!

### Step 4: Run the tests
To run the tests we generated, we first need to install some `RubyGems` using [Bundler](http://bundler.io/):
```shell
bundle install --without integration development
```

With this step completed, we can now run our tests whenever we want with the following command:
```
bundle exec rake spec
```

This command should give output similar to the following:
```
[root@pe-puppet mod_foo]# bundle exec rake spec
Cloning into 'spec/fixtures/modules/stdlib'...
remote: Counting objects: 8069, done.
remote: Compressing objects: 100% (6/6), done.
remote: Total 8069 (delta 1), reused 0 (delta 0), pack-reused 8063
Receiving objects: 100% (8069/8069), 1.67 MiB | 414.00 KiB/s, done.
Resolving deltas: 100% (3749/3749), done.
HEAD is now at da11903 Merge pull request #299 from apenney/432-release
/usr/bin/ruby -I/usr/local/share/gems/gems/rspec-core-3.4.4/lib:/usr/local/share/gems/gems/rspec-support-3.4.1/lib /usr/local/share/gems/gems/rspec-core-3.4.4/exe/rspec --pattern spec/\{classes,defines,unit,functions,hosts,integration,types\}/\*\*/\*_spec.rb --color

mod_foo
  should compile into a catalogue without dependency cycles

Deprecation Warnings:

Using `stub` from rspec-mocks' old `:should` syntax without explicitly enabling the syntax is deprecated. Use the new `:expect` syntax or explicitly enable `:should` instead. Called from /usr/local/share/gems/bundler/gems/hiera-puppet-helper-155f132c0b22/lib/hiera-puppet-helper.rb:23:in `block (2 levels) in <top (required)>'.


If you need more of the backtrace for any of these deprecations to
identify where to make the necessary changes, you can configure
`config.raise_errors_for_deprecations!`, and it will turn the
deprecation warnings into errors, giving you the full backtrace.

1 deprecation warning total

Finished in 1.92 seconds (files took 0.6783 seconds to load)
1 example, 0 failures
```
There's a few warnings in there which you could probably fix yourself if your interested, failing that a future version of Puppet-Retrospec may generate tests that fix this.

The important line here though is the last one:
```
1 example, 0 failures
```

Which means that our tests pass! - Great!

## Not so fast!
Our fixed module can go straight into production now right?  No!  Have another look at the class definition.  See the lines:
```
class mod_foo($do_stuff='') {
```
and
```
if $do_stuff {
```

One big gotcha with the Puppet 4 parser is that whereas `''` evaluated `false` in older versions of Puppet, in the Puppet 4 Parser this same code evaluates to `true`!

If your using the empty string `''` as a placeholder for False in your Puppet Modules then this is something you will want to fix before any rollout.

In my case, the fix is simple:  Since I'm not interested in any string value for the `do_stuff` variable, I can just change it to be `false`, giving me the fixed class definition:
```
class mod_foo($do_stuff=false) {
```

Rerunning my tests again indicates they are still passing - great!

## Further recommended testing
At this point I'm happy that the code I've written is syntax error free and creates the same resources it used to but I'd still recommend:
* Creating and running Puppet [smoke tests](https://docs.puppet.com/guides/tests_smoke.html) using the version of Puppet Enterprise your planning to deploy to (in another Vagrant VM!)
* Considering whether its worth writing additional tests to the ones generated by Puppet-Retrospec
* If your feeling really brave, you could have a look at doing acceptance testing (testing on real systems) using [Test Kitchen](http://kitchen.ci/) or [Beaker](https://github.com/puppetlabs/beaker).  Be warned that neither of these systems are particularly easy to use for doing testing on Puppet code (although it is possible...)

When your happy that your code has been tested enough, you can deploy it to a test Puppet Master.  Your final guard against misconfiguration would be to limit initial deployment to a handful of test nodes.  

Once the uplifted Puppet Module is proved working in the real world it can be considered for a wider rollout, perhaps along with the Catalog Preview tool mentioned earlier.

## What are the caveats of using Puppet-Retrospec?
The main _gotcha_ is that Puppet-Retrospec makes sure your code performs as coded which means that if you have errors in your Puppet code you will automatically have tests to ensure those errors are forever present in the generated Puppet catalogue!

There's very little that's going to beat _logical_ hand written, commented test cases but Puppet-Retrospec is great for generating the required test infrastructure in old modules and is a big help in getting customers across the line with their upgrades.

You can always edit the tests it generates to make them more useful too.

## What about new modules, should I use Puppet-Retrospec on them too?
You can certainly add RetroSpec to new modules if you wish, however, you may instead want to look at the `puppet module generate` subcommand which can be used to create a new _blank_ module complete with a basic set of tests.  

From here you just need to create a `fixtures.yml` file as described in [The Next Generation of Puppet Module Testing](https://puppet.com/blog/next-generation-of-puppet-module-testing) and you can then start writing a complete set of tests using RSpec Puppet.


## Troubleshooting

### I added some cool Puppet 4 code and now my tests fail!
Edit the file `spec/spec_helper.rb` and uncomment the line that says
```
ENV['FUTURE_PARSER'] = 'yes'
```

### I can't run RetroSpec Puppet anymore!
If you run the `retrospec puppet` command and all you see is the message
```
Successfully ran hook: /root/.retrospec/repos/retrospec-puppet-templates/clone-hook
```
Followed by no tests being generated, then its probably because you have a newer version of the `puppet` `RubyGem` installed then Puppet-Retrospec can handle.  You can prove this by running the command:
```
gem list | grep puppet
```
If you see any versions of `puppet` higher then version 3.8 (multiple versions are allowed), you need to remove them so that RetroSpec will use its _vendored_ version of Puppet, eg:
```
gem uninstall puppet
```
You can remove _all_ of the Puppet gems and next time you `bundle install` to run your tests, the correct version (3.8.7) will hopefully be installed.

### I can't get the bundle to install!
If your finding that running `bundle install` in your module directory cannot be made to work, make sure your not installing the gems in the `development` or `integration` groups (specifically the `guard-rake` `RubyGem`).  For some reason this `RubyGem` is not installable with Ruby 2.0 (RHEL 7), Ruby 2.1 (Ubuntu 15.10) or Ruby 2.2.2 (RHEL 7 + Software Collections).  I think I did manage to get it to install under Ruby 2.3 (Ubuntu 16.04) but then Puppet wouldn't work!  Basically it needs ruby 2.2.4 which you can install through [rbenv](https://github.com/rbenv/rbenv)/[RVM](https://rvm.io/)... or you could just not install it and move on with your life:
```
bundle install --without integration development
```

### I don't have a puppet command so I can't validate anything!
You need to install the `puppet` gem to gain access to this command.  If you've run through the `retrospec puppet ... bundle install ... bundle exec rake spec` cycle, then you will already have access but if this is your first time, you will need to install it manually:
```
gem install puppet -v 3.8.7
```
*Make sure to install ONLY this version of Puppet or you will break Puppet-Retrospec*

### My Puppet Code depends on other modules and my tests fail!
You probably just need to manually add any modules you depend on to the `.fixtures.yml` file, see [The Next Generation of Puppet Module Testing](https://puppet.com/blog/next-generation-of-puppet-module-testing) for more info.
