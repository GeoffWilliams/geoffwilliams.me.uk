# Docker Networking
The official reference for Docker Networking is can be found at https://docs.docker.com/articles/networking/ and is an interesting read but one that leaves many questions unanswered - notably _how the %$@! do I connect a container directly to my network_.

## 'Normal' Docker networking
By default, Docker will manage its own NATed network and will bind ports in the container to ports in the host.  This is fine for development work but doesn't really cut it when you want to put systems into production or eliminate NAT for performance reasons.

It is possible to manually configure individual bridges per container too, and the above linked document gives pages of instructions on how to do this but this wasn't really what I wanted either.


## Bridged mode networking
In the good old days of KVM and Xen, I used to set my host system with bridged mode networking and then create each VM configured to use its own instance of the bridged Ethernet adaptor.  Basically, it was as if each VM I was running was plugged directly into the local network.

This was simple, quick and easy - the three things I look for in a computer network and I wanted to do the same thing with Docker.

...Unfortunately, doing so is NOT easy right now and basically your options are to use Docker's officially supported networking techniques on the above page or use tools developed by the community to make the docker equivalent of easy bridged mode networking.

### Host setup
First thing to do is setup bridge mode networking on the host computer.  It's pretty simple to do this manually and once your bridge is in place you can use it wherever you like:
* [Debian](https://wiki.debian.org/BridgeNetworkConnections)
* [RHEL 7](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/sec-Network_Bridging_Using_the_Command_Line_Interface.html#sec-Create_a_Network_Bridge)

Once you've rebooted and have a `br0` your good to go configuring Docker to use it.

### Pipework
[Pipework](https://github.com/jpetazzo/pipework) is a BASH script that runs the right magic commands to get your container on the network.  To use it, you just put a copy of the script on your host computer somewhere and run the commands from there.

Pipework can do cool stuff like set a static IP address for your container or even get one for it via DHCP, with the DHCP client running on the *host* not the *container*.

with the above bridge setup as `br0` and the script executable and existing somewhere in your `$PATH` you can run commands like this:

#### Static address
```shell
pipework br0 MY_CONTAINER 192.168.1.50/24
```

#### DHCP address
```shell
pipework br0 MY_CONTAINER udhcpc
```
_requires that `udhcpc` is installed on the *host*_

Pipework is great for ad-hoc containers that you don't care about, but there's one big limitation and thats that the rules you make aren't persistent.  If you reboot (or just restart Docker) for some reason, you have to remember all of the commands you typed previously and run them once the containers are back up to restore connectivity.  This isn't really practical for any production-like scenario _unless_ you have some way of keeping an eye on your containers and re-running the commands needed.

Fortunately, someone [came up with a way to do just that](https://github.com/dreamcat4/docker-images/blob/master/pipework/README.md)

### Docker-Pipework
Of course the way this problem has been fixed is... a docker container!  [Docker-Pipework](https://github.com/dreamcat4/docker-images/blob/master/pipework/README.md).

The way this container works is really quite clever, if you follow the instructions in the readme, you end up with a container that automatically restarts itself (`--restart=always`) and then keeps an eye on the docker daemon via a volume mount so that the Docker-Pipework always knows when it needs to run the `pipework` script.

Your other applications are run with an extra argument which Docker-Pipework uses to reconfigure any containers it sees it on - neat eh?

#### Installation
Follow the instructions for [Pipework Container](https://github.com/dreamcat4/docker-images/blob/master/pipework/3.%20Examples.md#background-daemon).  This one command is all you need to download and run the daemon component of the system.  You can prove to yourself that its working by rebooting your Docker host and checking that the pipework container is still alive in the `docker ps` listing.

#### Container networking
The syntax for command to start your container with is given under the [Single Invocation](https://github.com/dreamcat4/docker-images/blob/master/pipework/3.%20Examples.md#single-invocation) heading.

Like the original pipework script, all of these commands are run on the host computer.

Assuming you have your bridge setup as `br0`, you can run commands like the ones below on your host and your containers will be automatically detected by Docker-Pipework and configured for network access - score!

The examples below are real commands for clarity.  `@CONTAINER_NAME@` gets replaced by the Docker-Pipework script at runtime.

##### Static address
```shell
docker run -d --restart=always --name='test1' --net=none -e 'pipework_cmd_ip=br0 -i eth0 @CONTAINER_NAME@ 192.168.1.70/24 ' jmoger/gitblit
```
Assign the IP address `192.168.1.70/24` to a container called `test1`, based on the image `jmoger/gitblit`

##### DHCP
```shell
docker run -d --restart=always --name='test1' --net=none -e 'pipework_cmd=br0 -i eth0 @CONTAINER_NAME@ udhcpc ' jmoger/gitblit
```
The [Docker-Pipework Examples](https://github.com/dreamcat4/docker-images/blob/master/pipework/3.%20Examples.md) all specify `dhcp` but you can use any [DHCP client](https://github.com/jpetazzo/pipework#dhcp) as long as its installed on the *host* computer.  In this case I've used `udhcpc` since I kept getting a `Network is down` error message when using `dhcp`.  

Incidentally, `dhcp` mode starts an additional, separate container to host the DHCP client - this is probably where my problems were coming from with this method.

When combined with a static allocated IP address from your DHCP server or dynamic DNS, this is a pretty cool way to setup networking in Docker.

##### Rebooting
Since the docker containers I want to run are marked to automatically restart (`--restart=always`) and the Docker-Pipework container is too, all the above example network configuration will survive a reboot or daemon restart - finally, _easy_ Docker networking!

## The future
Hopefully in the near future, this blog post will be redundant and giving an IP address to a container will be as simple as adding a flag to `docker run`.  Until then, happy bridged mode networking :)
