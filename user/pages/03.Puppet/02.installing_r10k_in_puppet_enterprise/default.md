---
title: Installing R10K in Puppet Enterprise
---

# Installing R10K in Puppet Enterprise

This is the 'Hard Way' of doing an R10K install for a new Puppet Enterprise system. If you want to go the 'Easy Way' there is an [R10K module](https://forge.puppetlabs.com/zack/r10k) on [Puppet Forge](https://forge.puppetlabs.com) which does all this work for you. For this exercise, I've chosen to do things the hard way so that I can get a good feel for how R10K works and what changes it needs to make to a system, since I'm going to need this knowledge in the future.

## Getting started

Once you've got your head around what R10K is trying to do and how your supposed to use it, there is a really good quickstart guide that details most of the steps you need to take to install R10K and the general installation approach. I found the steps I needed for Puppet Enterprise were:
 
### Step 1 – Install your Puppet Enterprise Puppet Master
Nothing special needed here, just a regular Puppet Enterprise install.
 
### Step 2 – Install or gain access to a git server
You need to ensure that only people who should be managing your Puppet infrastructure have access to this repository.
 
### Step 3 – Install r10k
You must install the R10K gem using the gem binary supplied with Puppet Enterprise.  For PE 3.7 you need to install the gem into the Puppet Server JRuby environment too and then restart the service.
```bash
# /opt/puppet/bin/gem install r10k
# /opt/puppet/bin/puppetserver gem install r10k
```

### Step 4 – Test that R10K was installed correctly
```bash
# /opt/puppet/bin/r10k help
```
 
### Step 5 – configure R10K
Create the R10K configuration file at /etc/r10k.yaml. The file format is described https://github.com/adrienthebo/r10k/blob/master/doc/dynamic-environments/configuration.mkd. The main goal here is to tell R10K where it can find your git server.
 
### Step 6 – Populate git
Populate the git repository for R10K with the set of skeleton files it requires and push them to the master branch. There is a section in the quickstart documentation that tells you how to manually create the required files or you can clone my r10k_quickstart repository and save yourself some typing. The r10k_quickstart repository sets up R10K the same way as the documentation and will give you NTP support after a successful run.
 
### Step 7 – Run R10K
This will put the files needed for environments into place, purging any files that are not under R10Ks control:
```bash
# /opt/puppet/bin/r10k deploy environment -v -p 
```
You can also selectively deploy environments and perform other tasks with the r10k command. See its online help (--help) for more information.
 
### Step 8 – configure Puppet Master
Adding/modifying the following configuration directives in puppet.conf
```
 [main]
 modulepath = $confdir/environments/$environment/modules:/opt/puppet/share/puppet/modules

 [master]
 manifest = $confdir/environments/$environment/site.pp
```
 
### Step 9 – configure Hiera
Change the value for datadir in the hiera configuration file at /etc/puppetlabs/puppet/hiera.yaml so that it interpolates the environment variable:
```
 :datadir: "/etc/puppetlabs/puppet/environments/%{::environment}/hiera"
```

### Step 10 – restart Puppet Master
```bash
# service pe-puppetserver restart
```
 
## Summary
You should now be using puppet with R10K. The R10K tool will automatically create one environment per branch in git, so initially you should have just one environment: 'master' matching the default git branch your using.
 
### Optional steps
#### Move control of all modules to R10K

In this initial configuration, there is a bit of inconsistency because the production environment (the puppet default) will source files from /etc/puppetlabs/puppet/modules/ and all other modules will source files from directories under /etc/puppetlabs/puppet/environments. It's easy to fix this and have everything served from the environments directory:

1. Create a branch called `production` in git. This should contain the module configuration you want to serve by default when a node doesn't specify an environment. These modules will be served instead of the ones at /etc/puppetlabs/puppet/modules.
2. Re-run the R10K command to create the files needed for the production environment
```
# /opt/puppet/bin/r10k deploy environment -v -p 
```
This will create a directory structure at /etc/puppetlabs/puppet/environments/production.
3. Remove or comment the [production] block in the puppet.conf file. ALL environments will now be sourced through R10K
4. Restart Puppet Master
```bash
# service pe-puppetserver restart
```
5. (Optional) Move the old puppet modules out of the way and leave a README in the directory so that future sysadmins know you switched to R10K

#### Remove the master branch
By default, git repositories ship with a default branch called 'master'. If this doesn't fit with the environments you had planed, you can fix this by deleting the 'master' branch:
```bash
$ git push origin --delete master 
```

After you've deleted the branch from your git server, rerun the R10K command and the unwanted 'master' directory will be removed from the environments directory

