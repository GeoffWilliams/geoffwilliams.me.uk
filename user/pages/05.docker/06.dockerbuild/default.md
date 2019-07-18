# dockerbuild
Last week I was asked the question _"how do I use Puppet manifests to build Docker images?"_

It's a good question one and one I myself was struggling with since I'd like to have a go at doing exactly that.  Turns out a few people have attempted this so far but they've all done so with private or highly customised solutions that involve installing puppet, running it and then removing it.  No one was aware of an easy way of doing what the question asked... so I created one.

## Introducing dockerbuild
dockerbuild is a system comprising a Docker image and a ruby script.  Together, they allow you to build docker images from your Puppet manifests without having to hack around with `Dockerfile`s or (other) custom scripts.

The idea is that with only 2-3 commands you can generate a Docker image from your puppet code, so that your up and running in minutes not days.

## Components

### puppet-dockerbuild.rb script
This [script](https://github.com/GeoffWilliams/puppet-dockerbuild) is the core of the system, it starts a docker image and mounts `/etc/puppetlabs` and `/opt/puppetlabs` from the host it is run on.  It then does `puppet apply` to include the requested class and commits the image.

### dockerbuild docker image
Strictly speaking, you don't need this docker image at all to run the `puppet-dockerbuild.rb` script.  It would work quite happily if you found a VM or server, installed Puppet Enterprise, Docker, all required gems and then ran the script.  Of course this is a bit of a pain to setup so to save others the effort all of these prerequisites are installed and configured within a downloadable Docker image.  There is a [script](https://github.com/GeoffWilliams/puppet_docker_images) which builds the image and pre-built images are available on my [Docker Hub](https://hub.docker.com/r/geoffwilliams/) page.


## Usage

### Step 0:  (Optional)  Build your own dockerbuild image
The [puppet_docker_images](https://github.com/GeoffWilliams/puppet_docker_images) project contains a script you can use to build your own Puppet Master and optionally do things such as connect it to your corporate r10k repository:
```shell
build_image.rb
  --pe-version 2015.2.1 \
  --tag-version 0 \
  --hostname puppet.megacorp.com \
  --r10k-control https://git.megacorp.com/control_repo \
  --dockerbuild
```

Once a customised image has been built, you can tag it and push it to your private docker repository.  
Note:  There is not support for authenticating to git servers at the moment


### Step 1:  Download and start the dockerbuild image
You can download and start the image using the `docker run` command eg:
```shell
docker run --privileged -d geoffwilliams/pe2015.2.3_centos-7_aio-master_public_lowmem_dockerbuild
```
This will start the container running and detach it to the background.  The container needs to be run in privileged mode for systemd to work correctly.  You will probably also want to look at options for naming your container and using specific directories as volumes.


### Step 2:  Populate with puppet code
If you built your own image and used r10k, then you can skip this step as your code is already on the system, otherwise you need to figure out a way to get some puppet modules installed.  To get your code into the container, you have a few options:
* `docker exec` to gain access to a shell inside the container, then download your puppet code, eg with the `r10k` command
* `/etc/puppetlabs/` is marked as a docker volume so just drop your code in there from the container your running on
* build your own dockerbuild image that has an initial download of your r10k control repository inside it.  This is directly supported by the [script](https://github.com/GeoffWilliams/puppet_docker_images) used to build the docker image, see the `--r10k-control` argument.
* if your just trying things out, you could use `docker exec` to install a module off the forge such as [puppetlabs/apache](https://github.com/puppetlabs/puppetlabs-apache) and then just set your role class to be `apache`.

Its worth noting that the design intention is to keep dockerbuild containers around for as long as a release of Puppet Enterprise is current, you might need to update the code hosted inside the image so it could be worth setting up systems such as MCollective to refresh the code when needed.

### Step 3:  Create a docker image
With the dockerbuild container running, your now able to use the docker instance running inside of it to make new Docker images.  For the moment, the easiest way to do this is probalby to use `docker exec` to gain shell access:
```shell
docker exec -ti CONTAINER_ID bash
```

You can then run the `puppet-dockerbuild.rb` script.  Since your puppet code and hiera data are temporarily mounted into this container, you have full access to all the data you need, as if you were running your code on a regular puppet master.

The script arguments specify the base docker image to use (`--base-image`), the output image name (`--output-image`) and the name of a puppet class to include with `puppet apply`.

Note:  your base image needs to be compatible (ie the same!) as the dockerbuild container (Centos 7 if downloading from the Docker Hub).

Example:
```shell
puppet_dockerbuild.rb --base-image centos \
                      --role-class apache \
                      --output-image DOCKER_IMAGE
```
* apache is good for testing, normally this would be something like role::webserver

### Step 3:  Done!
Once your image is built it will _live_ inside the dockerbuild container.  You can publish it to the docker hub or your own private Docker repository (these are manual steps at the moment).  Once available, you can then use normal Docker commands to create containers from your image, or you could use [garethr/docker](https://forge.puppetlabs.com/garethr/docker) and Puppet Enterprise to import and create containers from your new images.  Pretty cool eh?

## Caveats/todo
* Puppet code is not allowed to contain `service` resources or you will get failures.  There are no plans to fix this although a dummy service resource might at least stop Puppet code from breaking
* You have to manually push the images to your docker repository at the moment
* You should be running the same containerised OS as that of your puppet master container (currently hardcoded as Centos 7)
* We don't allow any Dockerfile tweaking at the moment, eg to expose ports, setup volumes, pick main processes, etc.
* This is experimental software, so use at own risk!
