---
title: OOMs in Puppet
---
# OOMs in Puppet
Out of memory errors can sometimes happen on your Puppet Master server when you haven't allocated enough RAM or swap to the VM your running it from (as I had - whoops). Unless you know what your looking for, you can spend hours investigating mysterious failures and strange tweaks that should do nothing yet seem to resolve the problems - albeit temporarily.

## Things to watch for

Symptoms of an Out Of Memory (OOM) condition include:
* Puppet runs failing for no apparent reason and then mysteriously recovering minutes or hours later
* It seems that your fixing things by restarting puppet, changing configuration files, etc. but eventually the problem comes back
* Strange errors when running `puppet agent -t` on the command line - looks like missing files or module paths

## Sample error message
In my case, I was getting error messages about the puppet console which sounded like files were missing to do with the puppet console - in fact these files were not loading because memory couldn't be allocated, not because the files were missing.

```bash
# puppet agent -t
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/iptables_persistent_version.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/os_maj_version.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/custom_auth_conf.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/pe_version.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/ip6tables_version.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/root_home.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/concat_basedir.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/facter_dot_d.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/pe_build.rb
Info: Loading facts in /var/opt/lib/pe-puppet/lib/facter/windows.rb
Error: Could not retrieve catalog from remote server: Error 400 on SERVER: Failed when searching for node client.puppetlabs.vm: Could not autoload puppet/indirector/node/console: cannot load such file -- puppetx/puppetlabs/pe_console/console_http
Warning: Not using cache on failed catalog
Error: Could not retrieve catalog; skipping run
Error: Could not send report: Error 400 on SERVER: Could not autoload puppet/reports/console: cannot load such file -- puppetx/puppetlabs/pe_console/console_http
```

## How to confirm diagnosis
The definitive test for out of memory errors is to check the logs and investigate matches:
```bash
# grep -i memory  /var/log/* -Rl
/var/log/anaconda.log
/var/log/anaconda.program.log
/var/log/anaconda.syslog
/var/log/dmesg
/var/log/dmesg.old
/var/log/messages
/var/log/messages-20140727
/var/log/messages-20140803
/var/log/pe-activemq/wrapper.log
/var/log/pe-activemq/activemq.log
```

A quick-and-easy way to detect most recent errors is to inspect the contents of the kernel ring buffer with the `dmesg` command:

```bash
# dmesg

... pages of output truncated

[ 9952]   491  9952    16349      607   0       0             0 postmaster
[ 9953]   491  9953    16349      637   0       0             0 postmaster
Out of memory: Kill process 8205 (java) score 244 or sacrifice child
Killed process 8205, UID 490, (java) total-vm:417912kB, anon-rss:106036kB, file-rss:80kB
```
As you can see, in this case the OS has been randomly killing processes to recover memory which explains the strange and random errors I was having.

## How to fix it

Thankfully the fix is simple - allocate sufficient memory (and/or swap) to the VM and you shouldn't encounter these kinds of errors any more ;-)
