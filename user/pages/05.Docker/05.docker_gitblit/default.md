# Docker GitBlit
If you need a local git server a really handy one is [gitblit](http://gitblit.com/).  You guessed it, it's available as a Docker container.

If your up-to-speed with [Docker networking](../docker_networking), then you can be up and running with a working git server within minutes:

## Exporting default data to the host
It's best to use a [volume](https://docs.docker.com/userguide/dockervolumes/) to store your git data at a handy location on the host, I chose to store my data under `/srv/docker/git.lan` since my server was going to be called `git.lan`.  

When using a *host directory*, it's necessary to put the initial copy of the data you want to share there yourself, as Docker won't do this for you (deliberately).

To get a functional system, the easiest thing to do was spin up a gitblit container, copy the files I wanted from `/opt/gitblit-data` and then destroy the container.

Here's what these commands look like:
```shell

# create our throw-away container
docker run -d jmoger/gitblit
bc8bcb2e6f58a94dc736ca9d730c3ddaea904517e6c945e5da592ffe4f2a9a4c

# copy the files from the container to the host directory
docker cp bc8bcb2e6f58a94dc736ca9d730c3ddaea904517e6c945e5da592ffe4f2a9a4c:/opt/gitblit-data /srv/docker/git.lan/data

# check files copied ok - looks good
ls /srv/docker/git.lan/data/
certs		    gitblit.properties	plugins		    serverTrustStore.jks  temp
default.properties  gitignore		projects.conf	    ssh-dsa-hostkey.pem   users.conf
git		    groovy		serverKeyStore.jks  ssh-rsa-hostkey.pem

# remove the container
docker rm -f bc8bcb2e6f58a94dc736ca9d730c3ddaea904517e6c945e5da592ffe4f2a9a4c
```

## Starting the container
Once these files are in place, you can start your proper gitblit container and have it configure itself for automatic restarts and bridge mode networking:

```shell
docker run -d --restart=always --name='git.lan' --volume /srv/docker/git.lan/data:/opt/gitblit-data --net=none -e 'pipework_cmd=br0 -i eth0 @CONTAINER_NAME@ udhcpc ' jmoger/gitblit
```

In a few seconds, you should have a fully working GUI git server available at whatever IP address your DHCP server allocated.  In my case I have dynamic DNS too so I just headed over to http://git.lan

...And that's all there is to it - now we have a functional network-connected git server after just a few minutes work.  Pretty cool hey!

## Next Steps
* Change your password!  The default is admin/admin
* Make sure you regularly backup the volume directory on your Host machine - that was why we made it external after all... ;-)
