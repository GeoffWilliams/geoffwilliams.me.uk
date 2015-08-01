# First Steps With Docker
[Docker](https://www.docker.com/).  Everyones talking about it but what can we actually do with the thing?

I wanted to have a go at controlling Docker with [puppet](http://puppetlabs.com) using the [garethr/docker](https://forge.puppetlabs.com/garethr/docker) forge module, but first I needed to learn a bit about Docker itself.

## First Impressions
First impressions are always important and having a look around the docker website you can see the overall theme is not one of boring terminal commands and OS internals but one of fun!

The first thing I see on the homepage is a picture of some cartoon animals chilling out on a tropical island.

This really is marketing genius - who doesn't like cartoon animals?

Looking at the picture, I see a whale (the docker logo) waiting helpfully in the harbor with a brick on his head while an octopus appears to be throwing bricks to him.

On the beach is an owl character chilling out with a margerita while the other characters do the work.

I like the sound of this already!

## Where to get started
Docker provide excellent training resources over at [training.docker.com](https://training.docker.com/).  I was going to do a short introduction to how to use each of the docker technologies here but there's really no need as the video tutorials on the training site are excellent and definitely worth sitting down and working through.

## Docker:  Killer features
* The application *and* its environment are the same from development through to production
* When configured, docker itself decides where to deploy and run your application
* With suitably developed applications, users are able to deploy micro-service architecture applications.  This allows components to be scaled horizontally or even swapped out altogether

## Abstraction layers
After a couple of days running through the docker tutorials, I started to think about ways I could abstract away running the individual docker commands into something more visible... like puppet code.

Next stop:  [garethr/docker](https://forge.puppetlabs.com/garethr/docker)
