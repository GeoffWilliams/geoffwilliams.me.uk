---
title: R10K and hiera-eyaml
---
# R10K and hiera-eyaml
[Hiera-eyaml](https://github.com/TomPoulton/hiera-eyaml) can be used as a drop-in replacement for the yaml backend to hiera.

Eyaml allows sysadmins to have encrypted values for plaintext keys and also plaintext values for plaintext keys.

The aim of this approach is to allow for easier debugging then you would have with a fully encrypted file but also better security then you would have with a fully plaintext file. It allows a few scenarios where you can share part of your hiera data with untrusted employees such as contractors without having them see your encrypted secrets – as long as you also keep your private keys safe(!)

## Upgrading R10K to hiera-eyaml
Upgrading to heira-eyaml is really easy even if your using R10K. If you follow the steps below, you will have encryption capabilities should you want to use them, but you don't have to immediately change anything which is really handy if you want to ease into things gently:

0. Read the [hiera-eyaml overview](https://github.com/TomPoulton/hiera-eyaml)
1. Install the hiera-eyaml gem:
```bash
# /opt/puppet/bin/gem install hiera-eyaml
# /opt/puppet/bin/puppetserver gem install hiera-eyaml
```
2. Generate keys and move them to a secure location
```bash
$ eyaml createkeys
```
Ensure file permissions on these files are as strict as the author suggests. Puppet Enterprise users should set ownership to user 'pe-puppet', group 'pe-puppet'.
3. Configure hiera to use the hiera-eyaml backend

Simply edit your `hiera.conf` file and change the 'yaml' backend to be 'eyaml' and the `:yaml:` section to be called `:eyaml:` providing a reference to where the key files are stored and optionally changing the file extension if you don't want to rename your existing `.yaml` files.

Here's a complete example:
```
:backends:
 - eyaml
:hierarchy:
 - "nodes/%{::fqdn}"
 - common

:eyaml:
 :datadir: "/etc/puppetlabs/puppet/environments/%{::environment}/hiera"
 :pkcs7_private_key: "/etc/puppetlabs/puppet/secret/keys/private_key.pkcs7.pem"
 :pkcs7_public_key:  "/etc/puppetlabs/puppet/secret/keys/public_key.pkcs7.pem"
 :extension: 'yaml'
```

After restarting the puppet master you should now have a functional heira-eyaml installation with full R10K integration. Follow the instructions it at the heira-eyaml site to start encrypting values you want to keep secret as required.

## Gotchas
Be aware that currently, when puppet decrypts values at runtime they will end up in the reports. See [this discussion](https://groups.google.com/a/puppetlabs.com/forum/#!searchin/pe-users/hiding$20sensitive$20data$20from$20reports/pe-users/iq1AuO7sXi4/WaPI_vgl5PwJ) for more information.
