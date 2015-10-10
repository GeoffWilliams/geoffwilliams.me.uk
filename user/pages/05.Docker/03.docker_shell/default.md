# Docker Shell
You can use [`docker attach`](https://docs.docker.com/reference/commandline/attach/) to connect to a running docker process but I always seem to get a blank screen when I try this, probably because I refuse to stick to the one-process-per-container paradigm to do tricks with systemd.

There's another way of getting a terminal on a docker container and thats to run the command:

```shell
docker exec -ti [CONTAINER-ID] bash
```
_Thanks [Stack Overflow](http://stackoverflow.com/a/30907056)_!

## Shell function
That's a fair few arguments to remember though and I'd like to be able to connect to my docker instances easily, especially since running ssh daemons inside of every container is [considered the work of the devil](https://jpetazzo.github.io/2014/06/23/docker-ssh-considered-evil/)

With a small bash function, I can make my life a lot easier.  I've created a simple shell function that wraps the above command in something easier to use.

### Installation
Copy and paste the script below into the `~/.bashrc` file of the user your run docker as (if running via sudo, you will likely have _issues_)

https://gist.github.com/GeoffWilliams/4654f62f62f139a7ef63

Then logout and back in again.

### Example
After installation, you will have a new docker subcommand: `shell`:
```shell
docker shell CONTAINER_ID
```

Thats all there is to it - now you can get access to a shell on your container just as easily as typing `vagrant ssh foo` ;-)
