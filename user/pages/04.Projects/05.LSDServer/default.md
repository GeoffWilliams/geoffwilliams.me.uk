---
title: LSDServer
---
# LSDServer
LSDServer is a Linked Sensor Data service written in Python.

It is currently incomplete and under development but aims to provide an easy way to register sensors and observations with the system and provide an interface to read the data back.

The main aim of this project is to support lightweight sensors attached to simple microcontrollers ([arduino](http://www.arduino.cc/)) or smartphones with the eventual goal of being able to provide a system to link sensors into more complex systems
Features

* REST + JSON interface
* [Flask](http://flask.pocoo.org/) used to provide REST api
* [SQLAlchemy](http://www.sqlalchemy.org/) used for multi database support

[GitHub project page](https://github.com/GeoffWilliams/lsdserver)
