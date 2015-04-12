---
title: WTF is R10K?
---
# WTF is R10K?

If you start doing any serious work with Puppet these days, you will hear people mentioning [R10K](https://github.com/puppetlabs/r10k) frequently.

It took me a while to get my head around what R10K actually does. First off, the scary sounding name has nothing to do with resistors or anything too technical. The name apparently means “Killer robot powered Puppet environment deployment”.

Unfortunately R10K isn't really a killer robot and while useful doesn't do all your work for you.

The best way I can think of to explain what R10K does is to say that it manages the contents of the puppet environments directory for you – and that is basically _ALL_ it does, although doing this would be a big job if you were to do everything manually.

## How does it work?
R10K works around the model of having a git directory for each module you want to puppet to use. Back in the day, the advice from Puppet Labs was to use one big git directory for the whole module structure but as its easier to share modules with these days, the advice is now to split things up to aid reuse and versioning.

## PuppetFile
Having a whole bunch of different git repositories and forge modules to manually download each time you wanted to do some work in Puppet would be a major pain and to get around this R10K uses a 'PuppetFile' to specify what modules puppet should be using and where it should get them from – eg a branch on github, the Puppet Forge, etc.

## Git
R10K expects to be able to connect to a git (or other scm) server to retrieve the puppet file, hiera data and a couple of other files it needs to configure itself.

## Branches
This is where the use of R10K really comes into its own. R10K takes full control of the environments directory and dynamically creates and deletes new environment subdirectories for each corresponding branch in git.

If you add a new git branch, an environment will be created. If you delete one, the corresponding environment will be deleted, so R10K drastically simplifies the difficulty of experimenting with environments.

Each environment has its own PuppetFile and heira data so each environment can have different versions of modules and different configuration data in heira.
When do changes happen?

It's important to note that R10K isn't a daemon and will only perform changes when it is executed. How you choose to run the tool is up to you. At it's simplest, you could just manually login to the puppet master and run it as required but this isn't convenient and its easy to forget this step when your focussing on other things.

Some other popular approaches include triggering R10K runs git hooks and CI actions. These typically involve a system SSHing into the puppet master and running the R10K command itself. Be very careful with this approach – your puppet master contains all of the secrets for your organisation's computer systems and should be protected accordingly. Another approach is to do something with MCO.

There isn't really much benefit to using continuous integration systems with R10K at the moment. There is nothing to 'compile' as such and if you have your git repository setup with the appropriate hooks, you can do syntax validation on your puppet code before the git server accepts a commit.

The way I see it, all R10K really needs to keep itself updated is to keep an eye on its git server and update itself if there are changes. I'm tempted to write a simple daemon to run on the puppet master to do this as it would avoid having to mess around with granting access to other systems, etc. I'll see what the panel has to say about this.

## How does puppet know about R10K?
Puppet and R10K are two completely separate system. Puppet has NO knowledge that R10K even exists. Puppet simply uses the directories that R10k creates for it.

It does this because of a couple of changes you make to the puppet.conf file when setting up R10K. Specifically:

```
[main]
modulepath = $confdir/environments/$environment/modules:/opt/puppet/share/puppet/modules 

[master]
manifest = $confdir/environments/$environment/site.pp 
```

These lines perform the 'magic' of virtual environments by attempting to look for files in the $environment directory. The value of `$environment` comes from the `--environment` command line argument, the _client_ `puppet.conf` file or an ENC.

This trick works because r10k has put files in the environment directory exactly where Puppet expects to find them. Therefore, if you attempt to request an environment that doesn't exist in git or you haven't run the R10K too since creating a new branch, you will get a file not found error and your puppet run will fail immediately.

## Block diagram
Visually, R10K looks something like this:
