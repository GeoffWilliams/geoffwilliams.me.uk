---
title: Policy base autosigning
---
# Policy based autosigning
Policy based autosigning works by running a script each time a new certificate signing request (CSR) comes in. The script is written by you, the user and tells puppet whether to accept the certificate (exit status 0) or to reject it (non zero exit status).

Your script can be written in anything you like as puppet will simply execute the file and pass the certname (hostname) and the CSR on STDIN (PEM-encoded). The idea here is that for autosigning, you can embed additional information in the CSR when provisioning nodes.

## Isn't it enough to just autosign based on the hostname and vanilla certificate
No. The reason for this is that the box generating the CSR (or the person controlling it...) has the ability to put whatever they want in the request. Public keys as contained in the PEM encoded CSR aren't useful for authenticating nodes because no chain of trust is established until the certificate has been signed.

Unless you add “something extra” to your CSR to establish trust, then you don't know where these requests are coming from or who they are controlled by. They could have been genuine or perhaps someone connected to your corporate LAN while sitting outside in a white transit van while smoking heavily – how can we fix this?

## Establishing trust
There are two main ways of establishing trust in CSRs when using puppet and these map nicely to the traditional security-focussed concepts of:

### Something I have...
A pre-shared key AKA shared secret can be embedded in the CSR – the script you write checks for this and grants/rejects access to puppet based on comparing the shared secrets

### Something I am...
This one's a bit trickier and mostly applies to cloud based services. One way of doing things is to embed the UUID of the node in the CSR and then have the script you write cross-check the UUID using the cloud provider's API to establish authenticity. This of-course requires that you trust the cloud api to handle spoofed UUIDs, etc. but since in this case your whole VM image is “in the cloud” this trust is implicit and frankly if this is broken you already have bigger problems.

## Worked Example
Lets have a go testing “something I have...” - a pre-shared key

### Modifying the puppet master
Edit the `puppet.conf` file in `/etc/puppetlabs/puppet` and a line to your `[master]` section:
```
autosign = yourscript
```
Where yourscript is the full path to your policy script.

I'm using a simple script called `check_csr.sh` written in BASH to do my checking.  Remember the script needs to be executable by the user your puppet master runs as – `pe-apache` in Puppet Enterprise 3.3.x.  You also need to restart the puppet master after changing this file:

```
/etc/init.d/pe-httpd restart
```
```
# puppet.conf
autosign = /etc/puppetlabs/puppet/check_csr.sh
```

#### Writing the script
to get started, I'll write a really simple script that always rejects requests and set it to be executable with `chmod +x`:
```bash
#!/bin/bash

# Always reject node requests...
exit 1
```

#### Testing the script:
Running the script on the command line shows I get the non-zero exit status I want so the script is finished for now
```bash
[root@master puppet]# /etc/puppetlabs/puppet/check_csr.sh
[root@master puppet]# echo $?
1
```

#### Modifying the default CSR
Now lets modify the CSR that agents generate.  We can control what additional data puppet writes to CSRs by creating a file called `csr_attributes.yaml` file in `/etc/puppetlabs/puppet`.

We're going to add an attribute called `challengePassword` containing our shared secret.  The completed file looks like this:

*csr_attributes.yaml*
```
custom_attributes:
  challengePassword: "your the best"
```

Now lets test if puppet is putting this extra data in our CSR by generating a new certificate request.  If a request has already been sent, we can force puppet to generate new certificates by deleteing the existing ones from the agent, like this (if the previous request was also signed on the master it can be deleted with `puppet cert clean`):  
```bash
rm /etc/puppetlabs/puppet/ssl/ -rf
```

Now we can re-run `puppet agent --test` and have a look at the new certificate it generates
```bash
[root@agent-0 puppet]# puppet agent --test
Info: Creating a new SSL key for agent-0.puppetlabs.vm
Info: Caching certificate for ca
Info: csr_attributes file loading from /etc/puppetlabs/puppet/csr_attributes.yaml
Info: Creating a new SSL certificate request for agent-0.puppetlabs.vm
Info: Certificate Request fingerprint (SHA256): A4:AA:41:2E:79:00:9D:92:BA:EE:58:75:F4:E7:91:A0:27:AB:84:A4:94:2E:83:96:F0:A2:52:08:49:F5:67:14
Info: Caching certificate for ca
Exiting; no certificate found and waitforcert is disabled
```

We can see that the csr_yaml file was used during this request from the debug output.  Lets check the value inside the certificate request which was sent to the master:

The command to do this (on the master!) is:
```bash
openssl req -noout -text -in /etc/puppetlabs/puppet/ssl/ca/requests/agent-0.puppetlabs.vm.pem
```

And in this example, the output I get looks like this:
```
Certificate Request:
   Data:
       Version: 0 (0x0)
       Subject: CN=agent-0.puppetlabs.vm
       Subject Public Key Info:
           Public Key Algorithm: rsaEncryption
               Public-Key: (4096 bit)
               Modulus:
                   00:da:eb:fb:3f:9d:76:1d:59:a4:67:26:9b:1d:6f:
                   b6:29:d7:da:1b:d7:e5:07:8a:77:45:f5:5d:9d:c0:
                   e3:13:14:a7:60:4b:8f:39:53:07:0e:8d:c6:50:e3:
                   a1:e5:dd:3f:5b:53:cf:4e:6b:33:2b:e3:85:7b:a8:
                   a3:06:93:9e:28:e2:51:4b:08:e3:3c:6a:0b:1b:a9:
                   22:92:eb:b4:0a:f7:b1:23:c3:3b:3f:ab:b9:df:73:
                   91:6d:9d:79:11:d5:5d:ed:29:f0:7e:4f:33:df:f3:
                   9d:84:51:e5:73:83:1f:97:0f:ec:98:a9:af:f0:d2:
                   16:ed:4b:09:ac:63:c7:d1:3e:e2:7e:5c:06:23:ce:
                   c1:42:37:95:5c:67:2a:ce:89:07:ac:0c:9b:28:29:
                   08:61:f0:ae:3a:02:96:f5:32:7c:b2:f3:d8:38:12:
                   f3:a9:eb:58:3d:d2:92:48:29:2c:e1:68:31:7f:db:
                   be:b6:14:50:45:09:f3:1e:dd:5b:ce:6a:a0:ae:ad:
                   45:93:b0:9a:52:88:20:38:55:4a:61:3c:8e:f5:72:
                   0f:ed:de:7e:2d:9d:66:71:e2:35:71:91:30:b4:e0:
                   d0:a9:c3:97:07:7c:b3:af:0c:e0:64:71:b0:61:0f:
                   a4:05:a3:31:2a:ab:35:c2:a8:98:1c:26:0c:05:19:
                   ca:46:38:16:7f:3b:f7:f4:29:75:92:43:3c:63:b0:
                   dd:2b:82:a2:54:c2:b2:39:19:6f:90:eb:6a:5b:bc:
                   53:3b:41:18:29:23:91:5f:28:b0:7a:5f:f6:34:db:
                   a0:07:41:4e:a9:1a:a3:e0:98:80:65:4c:43:58:33:
                   1d:47:52:ef:19:ed:da:1b:2c:ab:2b:f0:f7:02:6a:
                   f6:eb:d6:93:6d:8d:d5:9c:17:67:9f:de:d5:c5:c4:
                   47:f5:9d:54:fd:36:85:52:5d:29:15:d4:7d:59:97:
                   09:08:f3:fc:4b:53:89:26:a4:09:a4:be:a4:62:cb:
                   97:bf:7c:da:75:8a:71:70:65:ba:6d:33:77:d1:ec:
                   47:96:4b:4f:b3:92:11:a6:7f:54:5f:e7:c4:e2:d9:
                   ff:02:27:55:f5:0e:1c:51:d2:e2:1b:6c:7a:f4:48:
                   2f:58:72:34:6c:f9:58:6e:f1:c0:52:3a:b6:e5:e9:
                   0b:f9:7f:55:a7:de:6c:a4:e0:ca:ac:0c:d4:5a:0b:
                   4e:8c:b7:3a:95:ec:f6:9c:ad:4b:00:8c:59:86:d3:
                   2a:9f:be:42:47:1b:37:5c:7a:73:bc:d2:9e:6e:f8:
                   b4:b7:9e:fd:15:a0:d7:35:2b:b8:31:7c:3f:42:a5:
                   ca:45:40:72:6c:c8:69:a2:cc:d6:37:51:26:e8:4c:
                   ad:1d:f5
               Exponent: 65537 (0x10001)
       Attributes:
           challengePassword        :your the best
   Signature Algorithm: sha256WithRSAEncryption
        73:ed:3e:a0:dc:a0:68:3a:4d:2a:c3:3a:19:e6:8a:3f:68:2d:
        c6:f9:52:65:b8:78:89:3d:af:5a:f0:a8:02:50:a6:42:45:d0:
        65:10:59:00:91:8c:4d:d8:0c:36:4f:14:7b:3a:61:ff:f8:7b:
        9d:bb:f1:52:8f:5c:5e:70:ac:37:6f:89:e1:4c:bc:4e:3e:68:
        e4:a4:b6:f5:6a:32:cf:15:e4:5a:d0:0e:c6:15:3f:35:ba:60:
        cb:46:f1:7f:cb:ca:1f:85:63:3d:6f:80:63:e9:bb:d2:e3:9d:
        dc:bc:8f:e0:e7:96:ad:5d:3e:84:d4:bb:36:34:47:b3:da:b4:
        d0:77:28:62:5f:98:6e:fe:cc:f3:b1:ac:ad:e8:a8:ee:18:e6:
        47:6e:e1:6c:9d:95:d6:99:14:68:e7:e8:88:6d:17:43:22:b7:
        d0:b9:bc:55:a9:ba:85:25:ca:a6:18:49:48:e7:a4:0b:71:f5:
        8d:e2:41:cf:22:ca:dc:9f:6d:d9:e5:e8:0a:c9:f4:a2:9b:2a:
        b5:7b:96:96:72:9a:11:53:13:51:29:2c:f3:4f:46:15:dc:f4:
        c1:e5:21:b4:e1:96:b9:91:7f:de:69:e1:64:1a:08:ca:47:3a:
        2b:f3:8b:25:9b:8a:34:b1:6a:39:2b:f7:bb:95:aa:24:a3:93:
        d3:8a:f8:db:4f:ea:5d:d1:e1:01:b0:7b:8a:54:e6:1a:25:7f:
        f4:60:50:78:89:31:c9:e5:e9:c9:ff:29:e6:4d:64:4c:cd:77:
        b1:b3:ca:13:64:0f:4d:57:a4:fb:69:34:51:99:cb:c6:06:eb:
        2d:c1:b5:89:b9:f6:4e:de:f7:5e:57:32:82:2f:a3:f0:1c:c7:
        14:07:41:e9:d3:49:fe:b0:06:d9:b3:24:7d:0d:77:3b:85:f8:
        0d:02:d7:31:6e:7e:e0:6e:75:2e:8c:6d:65:39:ed:8a:1e:db:
        d5:00:3f:bf:4b:b2:46:48:f9:56:d0:3a:8e:c7:82:bf:65:d2:
        74:28:8f:9b:af:4f:cb:40:d9:be:a6:d6:30:0e:a5:bd:3c:78:
        81:3d:dd:cf:fd:2c:1b:45:f1:9d:cc:f9:58:1f:65:ca:26:f1:
        45:a4:ac:85:d2:78:86:ae:27:dc:ae:11:6f:d3:ee:76:db:b0:
        ed:40:74:83:fc:fd:d5:33:27:f3:d2:d9:d6:6f:7f:26:ea:a4:
        67:6a:41:c9:77:0a:36:cd:d9:dc:5f:f3:af:dd:6e:41:17:c3:
        fe:02:97:78:77:63:88:7d:b3:1f:e7:dc:cf:89:1f:58:3e:e5:
        47:80:7f:1a:98:2c:cf:e9:42:87:ae:ee:28:8c:6c:a6:a8:3d:
        c9:9b:6d:a4:0a:96:98:60
```
We can see the extra field `challengePassword` in the CSR so our client is setup correctly

If I do check the certificates waiting to be signed on the master, I can see the request still sitting there because the script I wrote always rejects autosigning (the exit 1 line) so far.

#### Fixing up the script
In this very basic example, I'll fix up the script to get the value of the shared secret using `awk` and compare it to a hard coded value.  As mentioned previously the certificate is passed to the script on STDIN, so I can use the `openssl` command to parse it and then find the value of `challengePassword` using `awk`.  The completed script looks like this:

*check_csr.sh*
```bash
#!/bin/bash

# define the shared secret we will accept to authenticate identity
SHARED_SECRET="your the best"

# capture the certname (hostname) used for the request
CERT_NAME=$1

# feed STDIN (file descriptor 0) to the openssl command and pipe
# the output to grep to get the sharedSecret supplied by the agent
# capturing the value in a variable called AGENT_SECRET
AGENT_SECRET=$(openssl req -noout -text
```

To test the script, I can feed it the CSR my agent generated and a dummy hostname to check I get the correct output like this:
```bash
[root@master ~]# cat /etc/puppetlabs/puppet/ssl/ca/requests/agent-0.puppetlabs.vm.pem | /etc/puppetlabs/puppet/check_csr.sh agent-0.puppetlabs.vm
authorised agent: agent-0.puppetlabs.vm
[root@master ~]# echo $?
0
```

Incoming CSRs are placed in the directory `/etc/puppetlabs/puppet/ssl/ca/requests`.  Since my lab agent is called 'agent-0.puppetlabs.vm' it's request is in a file called 'agent-0.puppetlabs.vm.pem'.  The script proves that the CSR has the correct shared secret and we can see that the script has exited with a value of 0 indicating puppet should authorise the node.  

To complete our very brief testing lets change the value of the `$SHARED_SECRET` variable in the script to check that we get the alert message and a non-zero exit status:

```bash
[root@master ~]# cat /etc/puppetlabs/puppet/ssl/ca/requests/agent-0.puppetlabs.vm.pem | /etc/puppetlabs/puppet/check_csr.sh agent-0.puppetlabs.vm
***!ALERT!*** incorrect or missing shared secret from agent-0.puppetlabs.vm
[root@master ~]# echo $?
1
```

The output looks good, lets put the script back how it was and try provisioning our agent-0 node again and see if it gets auto-signed.  Since we've been messing with certificates, we need to clean these up on both the client:
```bash
rm -rf /etc/puppetlabs/puppet/ssl
```
and the master:
```bash
puppet cert clean agent-0.puppetlabs.vm
```

After running `puppet agent --test` on the client, we can see that the autosigning did indeed work:
```bash
[root@agent-0 ~]# rm /etc/puppetlabs/puppet/ssl/ -rf
[root@agent-0 ~]# puppet agent -t
Info: Creating a new SSL key for agent-0.puppetlabs.vm
Info: Caching certificate for ca
Info: csr_attributes file loading from /etc/puppetlabs/puppet/csr_attributes.yaml
Info: Creating a new SSL certificate request for agent-0.puppetlabs.vm
Info: Certificate Request fingerprint (SHA256): E3:F5:5C:92:49:52:5E:69:BB:42:AC:2F:A3:FC:0D:70:E8:81:CF:55:65:19:44:21:56:AE:71:5A:08:0F:D1:38
Info: Caching certificate for agent-0.puppetlabs.vm
Info: Caching certificate_revocation_list for ca
Info: Caching certificate for ca
Info: Retrieving plugin
…
```

### Testing other agents don't get autosigned

The final part of our testing is to fire up another VM without the extra certificate information to check that it doesn't get autosigned.

To do this, I'll fire up a node called bogus.puppetlabs.vm and run `puppet agent --test` to make the initial certificate request.

This time, I get the message:

```bash
[root@bogus ~]# puppet agent --test
Info: Creating a new SSL key for bogus.puppetlabs.vm
Info: Caching certificate for ca
Info: csr_attributes file loading from /etc/puppetlabs/puppet/csr_attributes.yaml
Info: Creating a new SSL certificate request for bogus.puppetlabs.vm
Info: Certificate Request fingerprint (SHA256): 56:19:60:69:BC:2B:52:EC:C9:CC:14:BD:25:51:78:9E:61:A8:13:E1:7C:86:86:28:68:7F:66:5B:BE:69:85:7F
Info: Caching certificate for ca
Exiting; no certificate found and waitforcert is disabled
```

This proves the certificate wasn't autosigned and when we check on the master, we see the new CSR waiting to be signed (or rejected) manually:

```bash
[root@master ~]# puppet ca list
 bogus.puppetlabs.vm    (SHA256) 56:19:60:69:BC:2B:52:EC:C9:CC:14:BD:25:51:78:9E:61:A8:13:E1:7C:86:86:28:68:7F:66:5B:BE:69:85:7F
```

So CSRs that can't be automatically signed are put in the queue for manual action.

Ideas for how to automate this?

#### Master configuration
This only has to be done once so perhaps you could track this by using version control or writing a puppet module

#### Agent configuration
You could try baking the extra files needed to generate the CSR into your base OS image or use a provisioning tool such as vagrant to have them installed as part of the agent boot-strap process

#### Further information

For full technical details of certificate signing, see:
[Extending puppet CSRs](https://docs.puppetlabs.com/puppet/latest/reference/ssl_attributes_extensions.html)
[Policy based autosigning](https://docs.puppetlabs.com/puppet/latest/reference/ssl_autosign.html#policy-based-autosigning)

The example BASH script is attached to this article
