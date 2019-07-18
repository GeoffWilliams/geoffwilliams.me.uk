docker run --privileged -d geoffwilliams/pe2015.2.3_centos-7_aio-master_public_lowmem_dockerbuild:v0


docker run -ti --cap-add SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /run -v /run/lock dockerimages/docker-systemd:ubuntu15.04  /lib/systemd/systemd   systemd.unit=emergency.service

## Building your dockerbuild image
```
./build_image.rb --pe-version 2015.2.3 --tag-version 0 --hostname dockerbuild.lan.asio --r10k-control git://git.lan.asio/r10k-control.git  --lowmem --dockerbuild
```

## starting the dockerbuild container
It's already left running as part of the build process :D

If you need to start it from the image:
```
docker run --privileged -d NAME_OF_IMAGE
```

## Login to the dockerbuild container
```
docker exec -ti NAME_OF_CONTAINER bash
```
No need or SSH!  Systemd takes over the main console so this is a good way of 
getting a shell

## Updating the puppet code inside the image
```
docker exec a982920e61d4 /opt/puppetlabs/puppet/bin/r10k deploy environment -pv
```


## Making the image
```shell
/usr/local/bin/puppet-dockerbuild.rb --base-image central.lan.asio:5000/centos7-docker --role-class 'r_profile::apache' --output-image apache_test
```
First make the image. Note that we've based it on a systemd enabled base image!  Full instructions for centos at https://hub.docker.com/_/centos/

We could have also used the a ubuntu base image:  https://hub.docker.com/r/dockerimages/docker-systemd/

### How to fix aufs errors
The docker image running Puppet Enterprise doesn't work too good with aufs so you must add the option:
```
-s devicemapper
```
to `OPTIONS` in `/etc/sysconfig/docker`

And then restart docker to before making the image

## Tagging and pushing
If the build worked ok, your now ready to tag and push to you local docker repository:
```
docker tag aafcf5f39544  central.lan.asio:5000/centos7-apache
docker push central.lan.asio:5000/centos7-apache
```

## Testing the image
_On another computer running docker..._

start the image
```shell
docker run -ti -P --expose 80  --cap-add SYS_ADMIN -v /run -v /run/lock -v /sys/fs/cgroup:/sys/fs/cgroup  central.lan.asio:5000/centos7-apache
```


see what port the web server is running on 
```shell
geoff@monster:~/github/geoffwilliams.me.uk/user/pages/05.Docker/07.dockerbuild2$ docker ps
CONTAINER ID        IMAGE                                  COMMAND                  CREATED             STATUS              PORTS                                                                                                                        NAMES
45b57ed49e13        central.lan.asio:5000/centos7-apache   "/bin/sh -c /lib/syst"   2 minutes ago       Up 2 minutes        0.0.0.0:32804->80/tcp                                                                                                        naughty_northcutt
```

See if we get the index page
```shell
geoff@monster:~/github/geoffwilliams.me.uk/user/pages/05.Docker/07.dockerbuild2$ wget http://localhost:32804
--2015-11-29 23:57:39--  http://localhost:32804/
Resolving localhost (localhost)... 127.0.0.1
Connecting to localhost (localhost)|127.0.0.1|:32804... connected.
HTTP request sent, awaiting response... 200 OK
Length: 481 [text/html]
Saving to: 'index.html’

index.html                100%[======================================>]     481  --.-KB/s   in 0s     

2015-11-29 23:57:39 (39.6 MB/s) - 'index.html’ saved [481/481]

geoff@monster:~/github/geoffwilliams.me.uk/user/pages/05.Docker/07.dockerbuild2$ cat index.html 
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<html>
 <head>
  <title>Index of /</title>
 </head>
 <body>
<h1>Index of /</h1>
  <table>
   <tr><th valign="top"><img src="/icons/blank.gif" alt="[ICO]"></th><th><a href="?C=N;O=D">Name</a></th><th><a href="?C=M;O=A">Last modified</a></th><th><a href="?C=S;O=A">Size</a></th><th><a href="?C=D;O=A">Description</a></th></tr>
   <tr><th colspan="5"><hr></th></tr>
   <tr><th colspan="5"><hr></th></tr>
</table>
</body></html>
```
... it works!
