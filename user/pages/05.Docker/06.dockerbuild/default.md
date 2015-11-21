# dockerbuild
Last week I was asked the question _"how do I use Puppet manifests to build Docker images?"_

It's a good question one and one I myself was struggling with since I'd like to have a go at doing exactly that.  Turns out a few people have attempted this so far but they've all done so with private or highly customised solutions that involve installing puppet, running it and then removing it.  No one was aware of an easy way of doing what the question asked... so I created one.

## Introducing dockerbuild
Dockerbuild

Caveats:
* You should be running the same containerised OS as that of your puppet master container (currently hardcoded as Centos 7)
