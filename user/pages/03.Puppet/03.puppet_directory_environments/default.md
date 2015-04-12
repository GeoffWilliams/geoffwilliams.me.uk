---
title: Puppet directory environments
---
# Puppet directory environments vs config file environments
Puppet has allowed "environments" in the `puppet.conf` file for a long time but there's now a new way to create environments using a simple directory based approach called "directory environments".

Directory environments are thankfully really easy to setup

## Configuration
Out of the box, support for directory environments is baked into the current version of Puppet Enterprise. These instructions refer to PE 3.3.0

All the instructions are provided in detail over at https://docs.puppetlabs.com/puppet/latest/reference/environments_configuring.html. To get things going on my environment all I had to do was:

1. Enable directory environments in puppet.conf:
```
environmentpath = $confdir/environments
default_manfiest = $confdir/manifests
basemodulepath = $confdir/modules:/opt/puppet/share/puppet/modules
```
to `/etc/puppetlabs/puppet/puppet.conf` in the `[main]` section. Be sure to check you only have these variables defined once in the section!

2. Create the basic environment
*create a 'production' environment*
```
# mkdir -p /etc/puppetlabs/puppet/environments/production/{modules,manifests}
# cp /etc/puppetlabs/puppet/manifests/site.pp /etc/puppetlabs/puppet/environments/production/manifests
```
this was a fresh install so I didn't have any modules yet, if you want to copy an existing setup do:
```
# cp /etc/puppetlabs/puppet/modules/* /etc/puppetlabs/environments/production/modules -r
```
3. Restart the puppet master
```
# /etc/init.d/pe-httpd restart
```
4. Try things out
At this point you should have working directory environments. Yes it really is that simple for once!

To testing things out, I just ran
```
# puppet agent --test
```
on the puppet master and observed it working and reading files from the directory environment properly. I had previously broken things due to a typo in the basemodulepath variable so this was proof enough that things were working in this case. You could try removing (renaming if your cautious) your current puppet modules directory from `/etc/puppetlabs/puppet/modules` and see if everything still works

## Experimenting with directory environments

I created myself a new puppet environment called experimental by copying my existing production environment like this:

```
# cp -r /etc/puppetlabs/environments/production /etc/environments/experimental
```

After doing this, my new environment was ready for use. No restarting puppet master or editing the config file necessary. To prove things worked, I added a node to the manifests/site.pp file in experimental, installed the puppetlabs-apache module and classified my node with it in site.pp. A copy of my environments directory is attached to this blog post if you want full details.

Installing modules using the puppet module tool is a little different to normal if your using directory environments, you have to invoke it with the `--modulepath` directive. In my case, the command to install puppetlabs-apache into my experimental environment looked like this:

```
# puppet module install --modulepath /etc/puppetlabs/puppet/environments/experimental/modules/ puppetlabs-apache
```
I then tested things out by running `puppet agent --test` on the agent node and observed it sourcing its regular production environment. To test out the new experimental environment, I just ran puppet `agent --test --environment experimental` and watched it download and install apache. nice.

If you want to permanently 'pin' an agent to a particular environment, you just edit the `/etc/puppetlabs/puppet/puppet.conf` file on the agent node and sent an environment=xxx directive the same as you normally would for config file environments. The agent will then source its configuration from the environment you choose.

After setting things up, my environments directory structure looked like this:
```
/etc/puppetlabs/puppet/environments/
├── experimental
│   ├── manifests
│   └── modules
└── production
    ├── manifests
    └── modules
```

## Non-existant environments

What happens if you try to run puppet agent against an environment that doesn't exist? Lets try it and see what error we get:
```
# puppet agent --test --environment nothere
```
*this is the error you get for your reference...*
```
Warning: Unable to fetch my node definition, but the agent run will continue:
Warning: Find /nothere/node/agent-0.puppetlabs.vm?transaction_uuid=1f1abe13-4f33-4d35-878d-5db98466b413&fail_on_404=true resulted in 404 with the message: Not Found: Could not find environment 'nothere'
```
_followed by several screens full of error messages that I won't duplicate here_

Fixing this is pretty easy and the error is self explanatory too. All you need to do is make sure you use only environments that exist. That makes sense.

## So should I deploy my directory environments like this?
In a word: no! This post shows you how to get something working in the simplest possible way, but I haven't covered things like VC different branches for different environments, hiera or indeed anything to do with version control. I've edited files directly in the `/etc/puppetlabs/puppet` directory which you definitely don't want to be doing in a production environment but since this was in a controlled sandbox VM its of no consequence if I break anything.

I did things this way to demonstrate the minimum you need to do to get up and running. How you take this forward is up to you, but directory environments do integrate directly with R10K and there's a really good blog post on just how to do this over on [Shit Gary Says](http://garylarizza.com/blog/2014/08/31/r10k-plus-directory-environments/) should you wish to set things up 'properly'

## What about config file environments?
Full details of these are documented on the [puppletlabs documentation site](https://docs.puppetlabs.com/puppet/latest/reference/environments.html#directory-environments-vs-config-file-environments) but in a nut-shell, directory environments are a drop-in replacement for config file environments; work really simply; and do not require a restart of the puppet master.

Eventually directory environments are slated to replace config file environments completely and they also integrate nicely with R10K and as long as you resist the temptation to edit the different directories on your puppet master directly (as I've done in this blog post... ;) they give you an easy path to deploy different environments with Puppet.
