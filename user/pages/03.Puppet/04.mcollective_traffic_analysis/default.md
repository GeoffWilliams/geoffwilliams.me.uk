---
title: MCollective Traffic Analysis
---
# MCollective Traffic Analysis
This article describes the steps I took to perform traffic analysis on the Puppet Marionette Collective/ActiveMQ messaging system using wireshark and Linux commands.

## Method
Use wireshark on the virtual network interface to perform live packet capture, then analyse the conversation after logging into the console and performing a puppet run on the client VM using live management.

### Virtual network setup as follows:
| Host          | IP Address     |
| ------------- | -------------- |
| Workstation   | 172.16.173.1   |
| Puppet master | 172.16.173.128 |
| Puppet client | 172.16.173.129 |

Lets start having a look at that capture log:

So far we can just see HTTPS traffic to the puppet master.

Lets filter out all traffic from my workstation since we can assume its just HTTPS traffic to and from the puppet master (if we wanted to prove this we could use firebug in the browser).

Cool, now we can see the guts of the MC conversation.

The first line shows the MC port on puppet master talking to the client. Soon after (63) we can see the client talking to the puppet master. Pretty straight-forward right?

Only it isn't! Lets look closer at the first line. It has the TCP ACK flag set but we know that TCP conversations always start with a SYN flag and sequence number 0, not 1. Perhaps the filter messed things up. Lets change it to just follow this conversation.

Still nothing. This is all we have.

I tried capturing this a couple of times thinking something was wrong with wireshark or the virtual network until the penny dropped. There was no SYN packet because the connection must already be open!

Lets investigate this further on the client:

Here we can see that puppet is not currently executing as there is no lock file. Also We can see that there is an ongoing conversation to port 61613 (MC). This proves that the connection to MC is already established – now we just need to find out when and how this happens.

To do this, I shut down my entire lab, powered up the puppet master again and started network traffic capture. I then brought up the lab client and watched the traffic.

Bingo – the highlighted packet shows the SYN packet I was hunting for earlier, proving that the connection is made on startup and maintained while the puppet master is reachable.

The final piece of the puzzle is to see what program is running the conversation and how we can control it. Back on the client, I opened up a terminal and ran the commands below, revealing that a separate ruby process for mcollective is managing the connection. A quick look in /etc/init.d reveals its own init script along with a way of controlling the daemon.

This still leaves the question of how the actual communication between the console and the mcollective daemon takes place, so lets login to the console and start looking at the live management tab while capturing traffic on the loop back interface.

The capture shows lots of traffic on the loop-back interface to the mcollective port on 61613 (the operating system has optimised it away from appearing on the virtual Ethernet adaptor).

This proves that the console communicates with the mcollective daemon using a TCP/IP connection rather then another approach such as file sockets.

Logging in via SSH, I can examine the open connections to the mcollective daemon and find out what processes are responsible for them.

Of the interesting looking connections, the one that looks most promising is the Java process running with PID 17500.

To find the responsible process, I started shutting down promising looking parts of puppet using the init scripts at `/etc/init.d/pe-*`.

On my first attempt, I found pe-activemq. Calling this script with a stop argument caused the network connection to disappear.

A quick look into active MQ on Google reveals that it is Java messaging framework supporting multiple languages. The console almost certainly feeds directly into this system.

# Investigation summary
## Which part of the system initiates the connection
The MCollective ruby daemon, controlled by a script at `/etc/init.d/pe-mcollective` connects from the AGENT computer to the MASTER running on port 61613
What part sends the messages

The pe-mcollective daemon sends messages from the MASTER to the AGENT at the request of the user via the live management tab in the console.

## How are messages created?
Messages are created using Java/Active MQ system.

## How this technology would work in an enterprise and what issues might be presented with network security devices
Long running connections often pose problems for firewalls which usually close idle links after a period of time if traffic is being routed in cloud or split-site operations.

If there are thousands of agents active, the idle connections could start to place significant load on network infrastructure as switches and routers are required to track these open connections. It is possible to configure keep alive packets from MCO to be sent every few seconds but if you have a large amount of nodes, you risk performing a DOS attack on your own infrastructure if you do so.

I imagine this design choice was made to avoid the need to open up a management port on the agent computers.
