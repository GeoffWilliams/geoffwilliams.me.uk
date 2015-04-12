---
title: Environments in-depth
---
#Environments in-depth
Once your up and running with R10K, your environments are ready to use. You can associate a node system with an environment in one of the following ways:

## puppet.conf
You can request an environment in the `[agent]` section of `puppet.conf` by editing the `environment=` line. This defaults to 'production'

## command line.
If you just want to test an environment out, you can supply the `--environment=` command line argument when running puppet agent. Note that this will only apply to the current puppet run.

## ENC
If you use [external node classifiers](https://docs.puppetlabs.com/guides/external_nodes.html), you can specify the environment that should be used as part of your YAML output.

## Puppet console
Puppet Enterprise 3.7 and above include a built-in node classifier - the [Node Classifier](https://docs.puppetlabs.com/pe/latest/console_classes_groups.html)

## Where are files for each environment sourced from?
All directories in each environment, with the exception of the modules directory are sourced from the git repository that R10K is configured to read. The modules directory is built by processing the `PuppetFile` and sourcing modules from git, Puppet Forge, etc. R10K uses its own caching mechanism to make this process as efficient as possible.

## Git and environments
Let's have a look at how this works in action by creating a different environment applying it to a system and then deleting it. In the 'real' world you'd typically merge a tested environment back into some other branch but that's beyond the scope of what I want to demonstrate here.

### Creating a new environment
I already have three environments: development, staging and production. Lets make a new environment called 'experimental' and test it out on a node.
Before we start, lets have a look at the initial environments. In git we have:

```bash
# git branch
 development
* production
 staging
```
And in the puppet configuration directory, we have the following environments:
```bash
# ls /etc/puppetlabs/puppet/environments/
development  production  staging
```

We'll base the experimental branch on the development branch:
```bash
# git checkout development
Switched to branch 'development'
# git checkout -b experimental
Switched to a new branch 'experimental'
```

To prove to ourselves that the branches can be used to hold completely different modules, lets add an extra module to the development branch by editing the `PuppetFile` and adding the module puppetlabs-tftp which provides tftp (trival FTP) support.

This is done by adding a line to the `PuppetFile` and pushing the new branch to the git server

```bash
# git diff
diff --git a/Puppetfile b/Puppetfile
index 6be9faa..c80bcd1 100644
--- a/Puppetfile
+++ b/Puppetfile
@@ -13,6 +13,7 @@ mod 'mkrakowitzer/deploy'
mod 'puppetlabs/java'
mod 'yguenane/repoforge'
mod 'jay/console_env'
+mod 'puppetlabs/tftp'

# temporary git branch to enable start on boot
# mod 'mkrakowitzer/stash'

# git add Puppetfile
# git commit -m "added tftp module"
[experimental dac837e] added tftp module
1 files changed, 1 insertions(+), 0 deletions(-)
# git push origin experimental
Password:
Counting objects: 5, done.
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 329 bytes, done.
Total 3 (delta 2), reused 0 (delta 0)
To http://admin@172.16.173.131:7990/scm/pup/puppet.git
* [new branch]      experimental -> experimental
```

Once the new branch has been pushed, future runs of R10K will detect the new branch and create a corresponding new directory tree in the environments directory for it
```bash
# /opt/puppet/bin/r10k deploy environment -p
# ls /etc/puppetlabs/puppet/environments/
development  experimental  production  staging
```

If we look in the modules directory for the new environment, we can see the tftp module that we added to the `PuppetFile` was also installed. Note that this module is ONLY present in the experimental environment.
```bash
# ls /etc/puppetlabs/puppet/environments/experimental/modules/
apache  console_env  external_facts  java   ntp         profiles   roles  stdlib
concat  deploy       git_version     mysql  postgresql  repoforge  stash  tftp
```

At this point, the new environment is deployed and ready to use. You could apply the experimental environment to a puppet node for a single run by adding the `--environment` argument to a puppet run:
```bash
# puppet agent -t --environment=experimental
```

### Deleting an environment
Lets say we've now finished testing out our experimental branch and want to get rid of it off the puppetmaster. We can do this really easily by just deleting the branch from git and re-running the R10K tool:
```bash
# git checkout production
Switched to branch 'production'
# git branch -D experimental
Deleted branch experimental (was dac837e).
# git push origin --delete experimental
Password:
To http://admin@172.16.173.131:7990/scm/pup/puppet.git
- [deleted]         experimental
# /opt/puppet/bin/r10k deploy environment -v -p
# ls /etc/puppetlabs/puppet/environments/
development  production  staging
```

As you can see, the environment has now been completely deleted and is immediately no longer available. In this demonstration we simply deleted the branch but the same workflow applies to branch merges and this is how you would normally test out and merge tested changes back into your main environments.

### Working on an established branch
Once branches are established R10K will pick up the latest version of the files for each branch from git when the R10K tool is executed. If invoked with the -p argument, R10K will additionally process the `PuppetFile` which will refresh modules to either the latest version or a specific version if you have requested one.

We can show this in action by adding an extra hiera `.yaml` file to git for the development environment and then and watching it show up in the right place:
```bash
# ls /etc/puppetlabs/puppet/environments/development/hiera/nodes/
client.puppetlabs.vm.yaml  git.puppetlabs.vm.yaml  puppet.puppetlabs.vm.yaml
# touch hiera/nodes/newnode.puppetlabs.vm.yaml
# git add hiera/nodes/newnode.puppetlabs.vm.yaml
# git commit -m "added a new node def"
[development 77bb106] added a new node def
1 files changed, 0 insertions(+), 0 deletions(-)
create mode 100644 hiera/nodes/newnode.puppetlabs.vm.yaml (100%)
# git push origin development
Password:
Counting objects: 7, done.
Compressing objects: 100% (4/4), done.
Writing objects: 100% (4/4), 424 bytes, done.
Total 4 (delta 2), reused 0 (delta 0)
To http://admin@172.16.173.131:7990/scm/pup/puppet.git
  ad65611..77bb106  development -> development
# /opt/puppet/bin/r10k deploy environment -p
# ls /etc/puppetlabs/puppet/environments/development/hiera/nodes/
client.puppetlabs.vm.yaml  git.puppetlabs.vm.yaml  newnode.puppetlabs.vm.yaml  puppet.puppetlabs.vm.yaml
```

### Maintaining different environments
Lets take a closer look at the three environments that were already setup. Each of the environments in this case contain the same modules but different versions have been specified in the `PuppetFile` and different hiera data is also used.

In this way, we can pin production systems to stable 'tried and true' modules from [Puppet Forge](https://forge.puppetlabs.com/) while being able to experiment in the development environment with the latest module code from GitHub or your own organisation.

Each environment contains it's own hiera data so its really easy to specify differences between environments in this way if you need to. The `PuppetFile` for each environment looks like this:
#### development
```
forge 'forge.puppetlabs.com'

# Forge Modules
mod 'puppetlabs/ntp', '3.0.3'
mod 'puppetlabs/apache'
mod 'puppetlabs/stdlib', '4.2.2'
mod 'concat',
 :git => 'https://github.com/puppetlabs/puppetlabs-concat',
 :ref => '1.1.0'
mod 'puppetlabs/mysql'
mod 'puppetlabs/postgresql'
mod 'mkrakowitzer/deploy'
mod 'puppetlabs/java'
mod 'yguenane/repoforge'
mod 'jay/console_env'

# temporary git branch to enable start on boot
# mod 'mkrakowitzer/stash'
mod 'stash',
 :git => 'https://github.com/GeoffWilliams/puppet-stash',
 :ref => 'my_fixes'


# Git modules (from local stash server)
mod 'roles',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/roles.git',
 :ref => 'master'

mod 'profiles',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/profiles.git',
 :ref => 'master'

mod 'git_version',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/git_version.git',
 :ref => 'development'

mod 'external_facts',
 :git => "http://admin:admin@172.16.173.131:7990/scm/pup/external_facts.git",
 :ref => "master"

mod 'web_server',
 :git => "http://admin:admin@172.16.173.131:7990/scm/pup/web_server.git",
 :ref => "development"
```

#### staging
```
forge 'forge.puppetlabs.com'

# Forge Modules
mod 'puppetlabs/ntp', '3.0.3'
mod 'puppetlabs/apache'
mod 'stdlib',
 :git => 'https://github.com/puppetlabs/puppetlabs-stdlib',
 :ref => '4.1.0'
mod 'concat',
 :git => 'https://github.com/puppetlabs/puppetlabs-concat',
 :ref => '1.1.0'
mod 'puppetlabs/mysql'
mod 'puppetlabs/postgresql'
mod 'mkrakowitzer/deploy'
mod 'puppetlabs/java'
mod 'yguenane/repoforge'
mod 'jay/console_env'


# temporary git branch to enable start on boot
# mod 'mkrakowitzer/stash'
mod 'stash',
 :git => 'https://github.com/GeoffWilliams/puppet-stash',
 :ref => 'my_fixes'


# Git modules (from local stash server)
mod 'roles',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/roles.git',
 :ref => 'master'

mod 'profiles',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/profiles.git',
 :ref => 'master'

mod 'git_version',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/git_version.git',
 :ref => 'staging'

mod 'external_facts',
 :git => "http://admin:admin@172.16.173.131:7990/scm/pup/external_facts.git",
 :ref => "master"

mod 'web_server',
 :git => "http://admin:admin@172.16.173.131:7990/scm/pup/web_server.git",
 :ref => "staging"
```

#### production
```
forge 'forge.puppetlabs.com'

# Forge Modules
mod 'puppetlabs/ntp', '3.0.3'
mod 'puppetlabs/apache'
mod 'puppetlabs/stdlib'
mod 'puppetlabs/concat'
mod 'puppetlabs/mysql'
mod 'puppetlabs/postgresql'
mod 'mkrakowitzer/deploy'
mod 'puppetlabs/java'
mod 'yguenane/repoforge'
mod 'jay/console_env'
mod 'mkrakowitzer/stash'

# Git modules (from local stash server)
mod 'roles',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/roles.git',
 :ref => 'master'

mod 'profiles',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/profiles.git',
 :ref => 'master'

mod 'git_version',
 :git => 'http://admin:admin@172.16.173.131:7990/scm/pup/git_version.git',
 :ref => 'production'

mod 'web_server',
 :git => "http://admin:admin@172.16.173.131:7990/scm/pup/web_server.git",
 :ref => "production"
```

Here you can see that different versions of certain modules are used in different environments - sourced from GitHub, my own private git server and the forge. In the real world, you'd likely use this technique to workaround a problem your having thats fixed in a later version of a forge module.

I actually had ran into just such a problem with a third party stash module while researching this article highlighting this usage perfectly. In the production environment, I've chosen to use the forge module for mkrakowitzer/stash but in staging and development environments I'm using a version off my personal github account where I was able to fix these problems. To complete the exercise, I was able to submit pull requests via GitHub to the module author and these have now been merged into his source code so the next version will fix the problems I had.

### Hiera data
In addition to specifying modules, each environment ships its own hiera data and uses heira for node classification.

Nodes are classified according to the 'classes' list. Since I'm using the roles and profiles pattern, I only have to specify which class in the roles module this node will be using.

The remaining data gets picked up by the classes of the profiles module where it is then fed into other modules which do the real work of configuring the system. Since each environment has its own heira data, configuring environments differently is a breeze – you can typically use the exact same modules and just use different hiera data to configure your environments how you like them.

Below is a sample .yaml file to setup the web server in the production environment. In this case, I'm specifying things like database names, website names and passwords - all in the one file and without having to edit the modules files to do this at all.
```
---
classes:
- 'roles::web_server'

profiles::web_server::databases:
 - "db1"
 - "db2"
 - "db3"
 - "db4"
 - "db5"
profiles::web_server::root_password: "topsecret"

profiles::web_server::sites:
 - "site1.puppetlabs.vm"
 - "site2.puppetlabs.vm"
 - "site3.puppetlabs.vm"
 - "site4.puppetlabs.vm"
 - "site5.puppetlabs.vm"

profiles::web_server::server_address: "127.0.0.1"
profiles::web_server::vhost_dir: "/var/www/vhosts"
```
