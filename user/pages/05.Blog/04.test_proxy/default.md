---
title: Test HTTP proxy Vagrant box
---
# Test HTTP proxy Vagrant box
Have you ever been tasked with testing a proxy server and realise that you
first need to set one up?

I have... many times... so I've decided to make my life easier and produce a
vagrant box thats setup to supply a working proxy server with easy switching
between authenticated and open access.

To do this I wrote a quick bash 
[script](https://github.com/GeoffWilliams/stray_puppet_profiles/blob/master/files/proxy-select)
that calls some puppet scripts to switch between access settings:

![proxy dialogue](proxy_dialogue.png)

# Setup
1.  Have vagrant install the box file (currently uploading).  
2.  Then create a new VM based on the box
3.  Add a bridge mode nework adaptor in the `Vagrantfile`
```
  config.vm.network "public_network"
```
4.  Boot the VM
5.  Login via ssh and run `sudo proxy-select`.  This will allow you to pick the
    proxy settings you want.

# Usage
Once the proxy is up and running, you can access it via your test systems by
configuring the system under test to point at the public IP addres the machine
booted with.  The proxy runs on port 3128.

When testing systems, its essential that the non-proxied internet access be
disabled, otherwise tets cannot be conclusive.  One of the best ways to do this
is by setting up `iptables` rules to drop all outbound traffic on ports 80 and 
443.  This is a good simulation of what a corporate firewall will usually do:

```
/sbin/iptables -A OUTPUT -p tcp --destination-port 80 -j DROP
/sbin/iptables -A OUTPUT -p tcp --destination-port 443 -j DROP
```

Proxy access is then usually controlled on linux via the variables:
* http_proxy
* https_proxy
* no_proxy

To deactivate the above rules, simply stop the iptables service (on RHEL/
centos):
```
sudo service iptables stop
```

Many applications ignore these variables and need to be configured separately.

# Symptoms of proxy related problems
* Strange lockups of about 5 minutes accompanied by little to no system load
* Wrong sites being accessed if your DNS is not fully working
* Instant failures that make no sense
* Entire systems suddenly stop working for obvious reason
