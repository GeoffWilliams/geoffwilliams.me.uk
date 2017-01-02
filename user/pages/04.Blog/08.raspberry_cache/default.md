# Raspberry PI Cache
## Caching proxy server for apt-get with an old Raspberry PI and apt-cacher-ng
I used to have a caching proxy server on my router but these days its not been working too good.  Turns out the [Polipo](https://www.irif.fr/~jch/software/polipo/) software I was using isn't maintained any more and I kept getting random failures during the day.  Instead of spending hours fixing this, I decided to use an old Raspberry PI 1 that I had lying about.  There were a couple of Gotchas but here's the whole process:

## Basic Raspberry PI setup
1. Download the latest [Raspian](https://www.raspberrypi.org/downloads/raspbian/) minimal image
2. Find a large-ish SD card and [burn the image using `dd`](https://www.raspberrypi.org/documentation/installation/installing-images/linux.md)
3. Boot the raspberrypi from the SD card with monitor, keyboard and mouse plugged in
4. Login - username `pi` password `raspberry`
5. Configure wifi networking:
  1. Add the following text to `/etc/wpa_supplicant/wpa_supplicant.conf` (adjust as needed)
```
network={
ssid="YOURSIDHERE"
psk="YOURPASSWORDHERE"
proto=RSN
key_mgmt=WPA-PSK
pairwise=CCMP
auth_alg=OPEN
}
```
  2. Set the hostname in `/etc/hostname`
  3. Use your router to set a static IP address via DHCP (optional)
  4. Reboot to activate wifi

6. Update the system:

  ```
  apt-get update && sudo apt-get upgrade
  ```
7. Install ssh:

  ```
  apt-get install openssh
  ```

At this point you should have a functional PI with wifi and SSH, so disconnect the monitor and login as the `pi` user with your favourite ssh client.

## apt-cacher-ng setup
The `apt-cacher-ng` package that ships with Raspian at the time of writing (2017-01-02) is old and has a bug that prevents it from downloading the index files needed by modern systems.  It will give errors like this:

```
E: Failed to fetch http://security.ubuntu.com/ubuntu/dists/xenial-security/main/dep11/Components-amd64.yml  403  Forbidden file type or location

E: Failed to fetch http://au.archive.ubuntu.com/ubuntu/dists/xenial-updates/main/dep11/icons-64x64.tar  403  Forbidden file type or location
```

Fortunately for us, there is a pre-compiled version of 2.1 that ships in raspians `testing` distribution, so we can save ourselves a day of either figuring out how to cross-compile a new package or waiting for the PI to download and compile itself.

1. Update apt to use `testing`
Open `/etc/apt/sources.list` and change the first line to read:
  ```
  deb http://mirrordirector.raspbian.org/raspbian/ testing main contrib non-free rpi
  ```
2. `apt-get update && apt-get install -y apt-cacher-ng`  Assuming this works with no problems, you now have a ready to use apt proxy... now all you have to do is tell your computers to use it

## Client setup
We can setup apt to reconfigure itself every time it connects to a new network.  This is handy if your on a laptop and change networks frequently while needing to be able to download packages at all times.

This bit is really easy!
Just create a file at `/etc/network/if-up.d/apt-proxy` and chmod +x it, then paste in the contents of
https://gist.github.com/GeoffWilliams/8b3a1de8ba7971868c46, adjusting as necessary for your home network name.

To test it out, just restart your network using the wifi icon or:

```
systemct restart NetworkManager
```

Check the contents of `/etc/apt/apt.conf.d/10proxy` and you should see a line beginning `Acquire::http::Proxy`.  From now on you should be able to use the proxy server every time you use `apt-get` and once configured, so will all your other Debian/Ubuntu machines - `#winning`!




## Troubleshooting FAQ
Q: Can't connect to wifi!

A: Check the output of `iwlist wlan0 scan` for details, if you get an error about `wlan0` not being found, and have rebooted several times and changed power supplies, its possible that you have a defective wifi dongle, even if it used to work... see if you can smell burning ;-)

Q: I get errors about icons or content when I do `apt-get update`

A: Make sure you updated to apt-cacher-ng 2.1!  See above instructions
