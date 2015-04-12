---
title: Puppet Language Features
---
# Puppet Language Features

## Language features
To better understand some of the language features of puppet, I've been carrying out and documenting some experiments around scope, parameterized classes, defined resource types and resource defaults.

The module code developed for these experiments is available for download at the bottom of this page. Do not run it on production systems as it creates users, groups, etc.

## Parameterized classes with defaults from params.pp

If your writing parameterized classes, it's best to remove values for parameters from the business logic of your manifest for reasons of security and portability. Before the days of Hiera, the main way to doing this was to use a params.pp file to define variables externally of the manifests containing the business logic. A params.pp file should ONLY be used to define variables for use by other manifests later in the puppet run. Some logic (to set values according to operating system for example) is allowed but it should be kept to a minimum and there should certainly be no resources defined in one.

Because of the way puppet parses manifests, there are some quirks to be aware of when using this mechanism. In a nutshell, you have to use the inherits keyword or it won't work. This is about the only scenario where the use of inheritance is recommended.

## What happens if you just use include?
```
class parameterized::inc(
 $p_var1 = $::parameterized::params::var1,
) {
 include parameterized::params
 notify { "var1 = '${var1}'":}
 ->

 notify { "params::var1 = '${params::var1}'":}
 ->

 notify { "parameterized::params::var1 = '${::parameterized::params::var1}'":}
}
```
### Command
```
# puppet apply parameterized/tests/inc.pp
```
### Result
```
Warning: Scope(Class[Parameterized::Inc]): Could not look up qualified variable '::parameterized::params::var1'; class ::parameterized::params has not been evaluated
Notice: Compiled catalog for clienta.lab in environment production in 0.05 seconds
Notice: var1 = ''
Notice: /Stage[main]/Parameterized::Inc/Notify[var1 = '']/message: defined 'message' as 'var1 = '''
Notice: params::var1 = 'hello'
Notice: /Stage[main]/Parameterized::Inc/Notify[params::var1 = 'hello']/message: defined 'message' as 'params::var1 = 'hello''
Notice: parameterized::params::var1 = 'hello'
Notice: /Stage[main]/Parameterized::Inc/Notify[parameterized::params::var1 = 'hello']/message: defined 'message' as 'parameterized::params::var1 = 'hello''
Notice: Finished catalog run in 0.18 seconds
```
It looks logical and partially works but if you look closely at the output, you can see that there is an error printed to the console and the local $var1 variable is never set. The root cause of this error is that scope::params has not (YET!) been evaluated.
Using inheritance

To get the example to work, we must use inheritance by using the inherits keyword:
```
class parameterized::inher(
 $p_var1 = $::parameterized::params::var1,
) inherits parameterized::params {
 notify { "var1 = '${var1}'":}
 ->

 notify { "params::var1 = '${params::var1}'":}
 ->

 notify { "parameterized::params::var1 = '${::parameterized::params::var1}'":}
}
```
### Command
```
# puppet apply parameterized/tests/inher.pp
```
### Result
```
Notice: Compiled catalog for clienta.lab in environment production in 0.06 seconds
Notice: var1 = 'hello'
Notice: /Stage[main]/Parameterized::Inher/Notify[var1 = 'hello']/message: defined 'message' as 'var1 = 'hello''
Notice: params::var1 = 'hello'
Notice: /Stage[main]/Parameterized::Inher/Notify[params::var1 = 'hello']/message: defined 'message' as 'params::var1 = 'hello''
Notice: parameterized::params::var1 = 'hello'
Notice: /Stage[main]/Parameterized::Inher/Notify[parameterized::params::var1 = 'hello']/message: defined 'message' as 'parameterized::params::var1 = 'hello''
Notice: Finished catalog run in 0.19 seconds
```
By switching to the use of inherits vs include, we have altered the order in which the parser evaluates classes and this has caused the variables to be defined by the time they are needed this time around.

When specifying resources such as files, the advice from Puppet Labs is to either specify important attributes for each resource instance or to specify a resource default for each class.

The reason for this is because resource defaults are inherited from higher scopes if present. This can lead to important resource attributes being overridden with non-default values in ways which module authors fail to anticipate.

The classic example of this problem is file resources being created with incorrect ownership or permissions.
The following worked examples explain this in more detail.
Including another class

If a class is included that happens to specify resource defaults, they will be ignored for scopes ABOVE the class which defines them:
```
class resource_defaults::including::myclass {

 File {
   owner => "bob",
 }

 user { "bob":
   ensure => present,
 }
}
```
```
class resource_defaults::including::including {
 include resource_defaults::including::myclass

 file { "/tmp/resource_defaults__including":
   ensure => file,
 }
}
```
### Command
```
puppet apply resource_defaults/tests/including/init.pp
```
### Result
```
[root@clienta /etc/puppetlabs/puppet/modules]# ls -l /tmp/resource_defaults__including
-rw-r--r-- 1 root root 0 Jul  7 21:51 /tmp/resource_defaults__including
```
The ownership of the file by root proves that the resource defaults have not been applied, so we can be sure that by including another class we will never inherit its resource defaults.
Included by another class

When a class is included by another, resource defaults in higher scopes will apply:
```
class resource_defaults::included::included {
 include resource_defaults::included::myclass

 user { "charles":
   ensure => present,
 }

 File {
   owner => "charles",
 }

}
```
```
class resource_defaults::included::myclass {
 file { "/tmp/resource_defaults__included__myclass":
   ensure => file,
 }
}
```
### Command
```
# puppet apply resource_defaults/tests/included/included.pp
```
### Result
```
[root@clienta /etc/puppetlabs/puppet/modules]# ls -l /tmp/resource_defaults__included__myclass
-rw-r--r-- 1 charles root 0 Jul  7 22:11 /tmp/resource_defaults__included__myclass
```
## Cascading resource defaults

Resource defaults are cascaded through manifests and the defaults your module will receive are dependent on its position in the graph hierarchy that puppet builds when compiling the catalogue.

Consider the following class structure with the defaults for File resources being set in the resource_defaults::cascade::cascade and resource_defaults::cascade::cascade_1 classes

###Command
```
# puppet apply resource_defaults/tests/cascade/cascade.pp
```

###Result
```
[root@clienta /etc/puppetlabs/puppet/modules]# ls /tmp/resource_defaults__cascade* -l
-rw-r--r-- 1 alice alice 0 Jul  8 02:49 /tmp/resource_defaults__cascade
-rw-r--r-- 1 bob   bob   0 Jul  8 02:49 /tmp/resource_defaults__cascade__cascade_1
-rw-r--r-- 1 bob   bob   0 Jul  8 02:49 /tmp/resource_defaults__cascade__cascade_2
```
Running the puppet code creates files proving that resource defaults are cascaded via the include function in a predictable way. It's not a good idea to rely on this though as it then becomes necessary to inspect the entire hierarchy to determine which defaults are in effect.
Complex include hierarchies

Its possible to build complex hierarchies using the include keyword and this can lead to deterministic yet unpredictable application of resources defaults. Deterministic because puppet will always build graphs in the same way, but unpredictable because the reasons a graph has been built in a particular way are difficult for the average user to understand.

This is best illustrated with an example.

Here we have two classes, resource_defaults::complex::complex_a and resource_defaults::complex::complex_b which both set their own defaults for File resources and include another class called apache which creates a file resource by with whatever the current File resource defaults are.
Both of these classes are then included by the resource_defaults::complex::complex class.
### Command
```
# puppet apply resource_defaults/tests/complex/complex.pp
```
### Result
```
[root@clienta /etc/puppetlabs/puppet/modules]# ls -l /tmp/apache.conf
-rw-r--r-- 1 root alice 0 Jul  8 02:16 /tmp/apache.conf
```
After running puppet apply, you can see that puppet has picked up the defaults for the File resource defined in the resource_defaults::complex::complex_a class. Note that it has not combined the default file owner declared in the resource_defaults::complex::complex_b class. These defaults have been completely ignored because the choice of defaults to apply depends on the way that puppet builds its internal dependency graph.

In this particular experiment, I was able to influence the final graph created by altering the order of the include statements in the resource_defaults::complex::complex class. This resulted in a /tmp/apache.conf file owned by the bob user.

This was an interesting experiment but I would never recommend that you attempt to influence graph creation in this way on your production systems because this is a fragile mechanism and one which may disappear altogether in future version of puppet if the parser is changed.

Finally and probably most importantly it should be noted that the author of the apache module never intended for alice or bob to own the apache configuration file. I of course wanted it to be owned by root, but because I didn't bother to specify either ownership information or resource defaults in my apache class for this file, it picked up settings from a completely module!

For this reason, be sure to always specify owner, group and permissions for files you need to create with puppet – either directly within file resources or by using setting a resource default for your class.
## Defined Resource Types and Inheritance

Defined resource types do work as expected when using puppet inheritance – to the extent that the use of the inherits keyword for resource types is redundant. The inherits keyword is incompatible (parse error) with the define keyword but you are free to use defined resource types within classes so this is what I've investigated in the defined_resource_types module.

The module has the following structure:


The class defined_resource_types::base defines a type called my_dt(), attempts to override it in the class defined_resource_types::override and attempts to import the previously overridden defined type in the defined_resource_types class.
Testing each puppet class in turn gives the following results:
### Puppet code
```
class defined_resource_types inherits defined_resource_types::override {
}
```
### Command
```
# puppet apply ./defined_resource_types/tests/init.pp
```
### Expected result

The defined_resource_types class should inherit the definition of my_dt() from the defined_resource_types::override class
### Actual result

This is not allowed and results in an invalid resource type error:
```
Error: Puppet::Parser::AST::Resource failed with error ArgumentError: Invalid resource type defined_resource_types::my_dt at /etc/puppetlabs/puppet/modules/defined_resource_types/tests/init.pp:6 on node clienta.lab
Wrapped exception:
Invalid resource type defined_resource_types::my_dt
Error: Puppet::Parser::AST::Resource failed with error ArgumentError: Invalid resource type defined_resource_types::my_dt at /etc/puppetlabs/puppet/modules/defined_resource_types/tests/init.pp:6 on node clienta.lab
```
defined_resource_types::override
### Puppet code
```
class defined_resource_types::override inherits defined_resource_types::base {
 define my_dt($var1, $var2, $var3) {
   notify{"defined_resource_types::override::my_dt(${var1}, ${var2}, ${var3})":}
 }
}
```
### Command
```
# puppet apply ./defined_resource_types/tests/override.pp
```
### Expected result

The defined_resource_types::override class should override the definition of the my_dt type defined in defined_resource_types::base class
### Actual Result

The code executes as expected:
```
Notice: Compiled catalog for clienta.lab in environment production in 0.03 seconds
Notice: defined_resource_types::override::my_dt(a, b, c)
Notice: /Stage[main]/Main/Defined_resource_types::Override::My_dt[test]/Notify[defined_resource_types::override::my_dt(a, b, c)]/message: defined 'message' as 'defined_resource_types::override::my_dt(a, b, c)'
Notice: defined_resource_types::base::my_dt(a, b, c)
Notice: /Stage[main]/Main/Defined_resource_types::Base::My_dt[test]/Notify[defined_resource_types::base::my_dt(a, b, c)]/message: defined 'message' as 'defined_resource_types::base::my_dt(a, b, c)'
Notice: Finished catalog run in 0.19 seconds
```
However, it is necessary to qualify the defined type with the class name when using it:
```
defined_resource_types::override::my_dt { "test":
   var1 => "a",
   var2 => "b",
   var3 => "c",
}

defined_resource_types::base::my_dt { "test":
   var1 => "a",
   var2 => "b",
   var3 => "c",
}
```
Since the name of the defined type must be qualified, any advantage from using inheritance is lost, since you could have just done this in the first place by simply using the defined type directly.
Defined resource types with default values in params.pp

Using default values from a params.pp file with defined resources is difficult, due to the order that the parser evaluates manifests, you need to 'trick' it into first including the params.pp file before you can refer to it in your defined resource type.

An example of this can be found in the defined_resource_types::defaults type:
```
define defined_resource_types::defaults(
   $var1 = $::defined_resource_types::params::var1) {

 notify {"var1 is ${var1}":}
}

include defined_resource_types::params
defined_resource_types::defaults{"test":}
```
### Command
```
# puppet apply defined_resource_types/tests/defaults.pp
```
### Result
```
::defined_resource_types::params has not been evaluated
Notice: Compiled catalog for clienta.lab in environment production in 0.02 seconds
Notice: var1 is
Notice: /Stage[main]/Main/Defined_resource_types::Defaults[test]/Notify[var1 is ]/message: defined 'message' as 'var1 is '
Notice: Finished catalog run in 0.16 seconds
```
The magic that makes this work is the include on defined_resource_types::params in the test file. Without this line you will get a runtime warning from puppet and the test variable will never be set:
```
Warning: Scope(Defined_resource_types::Defaults[test]): Could not look up qualified variable '::defined_resource_types::params::var1'; class ::defined_resource_types::params has not been evaluated
```
This hack can be seen in action in the puppet labs supported apache module for the apache::vhost type.
Issues from using inheritance

Aside from the quirks around using defined resource types with inheritance, the general consensus is that inheritance in puppet manifests should be avoided wherever possible. The main reason for this is that modules using inheritance are much more difficult to understand and troubleshoot because it becomes unclear where actions are carried out and variables are set.

Often the only real way to debug things is to edit the manifests and insert a bunch of notify statements to identify where code is being executed.

You can get nearly all the advantages of inheritance in puppet by simply including the class you would have normally extended in the vast majority of cases.
