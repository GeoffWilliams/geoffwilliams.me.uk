# How to tackle a bug in Puppet Server

## The pen is mightier than the sword
As I like to teach students in my courses, pretty much *the* most useful weapon
you have in your armory.  It's your easiest and best way to prove that a
particular piece of code is being executed.

With that in mind, lets try and figure out "hello, world!" for Clojure.

### Installing Clojure support
It seems that [Leiningen](http://leiningen.org) is the de-facto program used to compile Clojure code,
analogous to make or maven for C or Java code respectively.

Unfortunately, unlike the above programs, Leiningen is not package for Debian/
Ubuntu anymore https://packages.debian.org/sid/leiningen gives a message saying
that the package has been removed from the distibution.  Presumably because the
packaged version was really old and no one wants to maintain the newer version.

On Debian/Ubuntu this means your left with the option of downloading and 
executing a script to install the software, which you can find in the 
[installation instructions](http://leiningen.org/#install).

## Hello, World
Once the software in installed your ready to write your first program and test
your setup, or rather you would be if you weren't in a desperate hurry like me!

There are some good resources out there for getting to grips with 
Clojure/Leiningen and if I'd had more time (along with a burning desire to 
learn Clojure) I'd take a look at some of them
* http://ben.vandgrift.com/2013/03/13/clojure-hello-world.html
* https://clojurebridge.github.io/community-docs/docs/getting-started/helloworld/

Instead, what I'm going to do is download a copy of the [Puppet Server source code](https://github.com/puppetlabs/puppet-server)
and sprinkle a few print statements through the code until I can confirm that
my code is being executed.

After (forking) and cloning the repository, I 
