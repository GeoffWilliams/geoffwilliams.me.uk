---
title: Updating R10K with git hooks and MCollective
---
# Updating R10K with git hooks and MCollective
Manually updating R10K after changes are pushed to git is a major pain.

There are a few ways this can be made to work transparently and this article discusses one possible option: Using a post-receive hook to publish an R10K update request to MCollective.

## Overview
All of the scripts and software to do this task already exists on the Internet, so all we have to do is plug things together to get it working.

There's a Forge [Module](https://github.com/acidprime/r10k) that does all the work.

While researching this article, I did the steps the puppet module does manually so that I could better understand what was going on. The Steps to get R10K updates working with Puppet Enterprise are:

1. Install MCollective client on the git server and get it talking to the puppet master
2. Install the R10K plugins for MCollective
3. Install a post-receive hook into the git server
I'm using the Atlassian Stash git server to research this article

## Installation
1. Install MCollective client and certificates on machine running git server
Support for MCollective is available by installing the pe-mcollective-client package on the git server. Follow the instructions in the r10K puppet module documentation to install the RPM and copy the certificates and configuration files to your git server.

In my case, I was running my stash server as a user called 'stash' so I had to change the MCollective configuration file and accordingly.

2. Test MCollective functionality from git server
Once MCollective is setup on the git server, you can try it out by becoming the user who's allowed to run the `mco` command ('stash' in my case) and then typing 'mco ping'.

If you get output that looks like this, it's working:
```bash
   [root@git ~]# sudo -u stash /opt/puppet/bin/mco ping
   puppet.puppetlabs.vm                     time=123.93 ms
   git.puppetlabs.vm                        time=125.38 ms


   ---- ping statistics ----
   2 replies max: 125.38 min: 123.93 avg: 124.66
```
3. Install MCollective plugins for R10K
To install the MCollective plugins, I manually copied the following directories from the unpacked puppet module to the place MCollective expects to find it:
```bash
   # cp files/agent /opt/puppet/libexec/mcollective/mcollective/ -r
   # cp files/application /opt/puppet/libexec/mcollective/mcollective/ -r
```
The module can of-course do this automatically but this is a learning exercise ;-)

Note that this must be done on both the puppet master and the git server! There is no mechanism to automatically distribute MCollective plugins unless you get the module to manually copy the files for you.

Once you've installed the plugins you must restart both MCollective servers:
```bash
# /etc/init.d/pe-mcollective restart
```

4. Test R10K MCollective functionality on git server
To test the newly installed R10K plugin I pushed some git changes and then ran the plugin. To check everything worked, I inspected the puppet code on the server to make sure it had been updated.

Running the synchronize command manually looks like this:
```bash
# sudo -u stash /opt/puppet/bin/mco r10k synchronize

* [ ============================================================> ] 2 / 2

git.puppetlabs.vm:
puppet.puppetlabs.vm:

Finished processing 2 / 2 hosts in 1138.35 ms
```

5. Install post-receive hook in git repository
Unfortunately the Stash web front-end doesn't support an easy way to add post receive hooks to git without buying them but once you've located the repository on disk it's possible to add hooks manually by dropping them inside the repository's `hooks/post-receive.d` directory. If doing this, start your filename with a number to control execution order.

You can find a complete hook script inside the R10K module in the file `files/post-receive` I had to comment line 5 (repository=...) to get the hook to work on my system

6. Test the whole process
You should now be able to do an end-to-end test of the system. Try making a change to your `PuppetFile` in git and push the changes to your git server. After a few minutes your changes should be live on the puppet master (it can take a while to update if you have a few modules to download)

## Troubleshooting
If things don't work, test the components individually until you find the fault:

### R10K
* Test manually running the R10K synchronize command on the puppet master:
```bash
# /opt/puppet/bin/r10k deploy environment -pv
```
* The MCollective plugin expects to be able to find the `r10k` command in the search path (`$PATH` variable). I had to symlink the `r10k` executable from `/opt/puppet/bin/r10` to `/usr/bin/r10k` to get the plugin to work

## MCollective
* Test MCollective is working with the `mco ping` command. If there are problems try restarting the `pe-mcollective` daemon and ensure clocks are synchronized.
* Make sure the R10K plugin is installed and working on both the puppet master and the git server. You have to do this by manually copying the files if your not having the forge module do it for you
* Increase the logging output for MCollective by editing the file /etc/puppetlabs/mcollective/server.cfg and restarting the pe-mcollective daemon and checking the output in the log file
* If debug output doesn't help, you could try putting extra logging into the MCollective pluggin to log to a file but don't forget you must re-start the pe-mcollective daemon for changes to take effect

## Git hook
* Check the git hook has execute permission (`chmod +x`)
* Carefully look at the output of the git push command - there may be a script error hiding in there
* Ensure the ruby interpreter runs when you type `/usr/bin/env ruby`. You may need a symlink if not
* Alter the hook to add debug output and log it to a file somewhere
