# Anatomy of an Augeas Bug

Sometimes you get one of those bugs that requires a completely different
mindset to the ones you normally get to fix:
* No stack trace
* No clear error message
* Tons of [Regular Expressions](https://en.wikipedia.org/wiki/Regular_expression)
* An unfamiliar language
* ... No problem!

## What is Augeas anyway?
[Augeas](http://augeas.net/) is a neat system for parsing and updating files.
This makes it a really handy tool when you need to selectivly _edit_ files you
don't own.

Augeas is context-aware, so it understands things like the level of nesting in
XML files and understands the propper grammar for files it's editing.  It does
this through an extra bit of code called a [lens](http://augeas.net/docs/lenses.html).

Lenses are the bit of magic glue that makes the whole system work and 99% of
the time you don't need to know or care about anything to do with them... 
Unless you stumble on an unsupported file-type or a bug as in this case. 

# Discovery and fault isolation
The customer was getting an error from Augeas whenever he had a line like:
```sudoers
%sportshorseracingopssudoers ALL=(ALL) ALL, !DISALLOWED
```
in `/etc/sudoers`.  Basically Augeas refused to process the file once this
line was present and works again if the `!` character is removed from the
command alias.  Problem isolated.

A bit more information was visible by getting Augeas to scan all files it 
_knows_ about:

```
[root@master ~]# augtool print /augeas//error
/augeas/files/etc/sudoers/error = "parse_failed"
/augeas/files/etc/sudoers/error/pos = "3796"
/augeas/files/etc/sudoers/error/line = "117"
/augeas/files/etc/sudoers/error/char = "0"
/augeas/files/etc/sudoers/error/lens = "/opt/puppet/share/augeas/lenses/dist/sudoers.aug:529.10-.70:"
/augeas/files/etc/sudoers/error/message = "Iterated lens matched less than it should"
```
So this is all I had to go on.

## Hazy memories from Back In The Day
As soon as I saw "matches less then it should", I was immediately transported
back to my carefree days at Uni which looked a bit like this:

![Happy Dayss...](the_pav.png)

...And immediately thought how that sounded exactly like a regular expression
that wasn't consuming enough characters.

## Finding the lens file
I'm a great believer in never bothering to remember paths to files since its
too much like hard work.  Instead I always use find, which is lightning fast
on small VM filesystems:
```shell
[root@master vagrant]# find / -iname '*lens*'
/usr/share/augeas/lenses
/opt/puppet/share/augeas/lenses
```

Since this is a Puppet Enterprise system, I knew to look in `/opt/puppet/share/augeas/lenses`
and from here it only took a couple of seconds to find sudoers lens at `/opt/puppet/share/augeas/lenses/dist`.

## Inside the Lens file
Once I opened the lens file and started looking around even more memories came
flooding back.  This time about [Context-Free Grammars](https://en.wikipedia.org/wiki/Context-free_grammar).

For the uninitiated, context-free grammars define the rules by which a string
or data structure is parsed and converted into a [parse-tree](https://en.wikipedia.org/wiki/Parse_tree).

Basically, this is how you write a language compiler.

Inside the lens file, I saw this code::
```augeas
let lns = ( empty | comment | includedir | alias | defaults | spec )*
```
Which is clearly a the top level entry point into the CFG.

What this line is saying is that the node `lns` can be rewritten *ONE* of the
following nodes:
* `empty`
* `comment`
* `includedir`
* `alias`
* `defaults`
* `spec`

Lets have a look at the simplest one of these nodes: `empty`
```augeas
(* View: empty
Map empty lines *)
let empty   = [ del /[ \t]*#?[ \t]*\n/ "\n" ]
```
So far, so good.  This looks like it matches and strips a bunch of whitespace 
characters.  Note the newline `\n` at end of the line.  I found out later that 
this is vital!  Miss it off and *nothing* will work as the line isn't treated 
as finished.

After having a look at some of the other nodes, I eventually found the one I was
interested in: `spec` which looked like this:
```augeas
let spec = [ label "spec" . indent
               . alias_list "user" sto_to_com_user . sep_cont
               . Build.opt_list spec_list sep_col
               . comment_or_eol ]
```

Following the production rules, I eventually ended up at this fragment of code:
```
(* Variable: sto_to_com_cmnd
sto_to_com_cmnd does not begin or end with a space *)
let sto_to_com_cmnd =
      let alias = Rx.word - /(NO)?(PASSWD|EXEC|SETENV)/
   in let non_alias = /(!?[\/a-z]([^,:#()\n\\]|\\\\[=:,\\])*[^,=:#() \t\n\\])|[^,=:#() \t\n\\]/
   in store (alias | non_alias)
```

Which basically matches a regular expression word (`/\w+/`) followed by some 
optional flags or a literal command (non-alias).  Looking closely, we can see
that the non aliases are allowed to start with an optional `!` character but
the aliases are not (we're missing the `/!?/` bit).

## Now what?
It was time for a bit of research to see how to fix this properly in order to
get the best chance of having a fix accepted upstream.  I found [this](https://stomp.colorado.edu/blog/blog/2011/01/07/on-finding-and-fixing-augeas-parse-errors/) page which was really helpful
and definitely worth a read.

## Writing the testcase
The site above goes into lots of detail about testcases in Augeas.  For this
bug, all I needed to do was edit the file at /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
and add a new testcase to the bottom of the file.  Running the tests was as simple as typing:
```
augparse /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
```

Once I'd written a testcase which seemed to be doing something by copying the 
other examples, I went back in the lens file and started making changes.  The 
obvious place was the `sto_to_com_cmnd` function and I was able to prepend an
 optional `!` character to the start of the `let alias` rule.

The only problem was this didn't work!

I got a ton of errors like this:
```shell
[root@master ~]# augparse /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
Syntax error in lens definition
/opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug:329:8: Unexpected character \
/opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug:329.8-.33:syntax error, unexpected UIDENT, expecting '}'
/opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug:syntax error
[root@master ~]# vim /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug 
[root@master ~]# augparse /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
Syntax error in lens definition
```

and then this:
```shell
[root@master ~]# augparse /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
/opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug:321.0-330.3:exception thrown in test
/opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug:321.5-.62:exception: Input string does not match at all
    Lens: /opt/puppet/share/augeas/lenses/dist/sudoers.aug:510.11-513.33:
    Error encountered at 1:0 (0 characters into string)
                               <|=|%opssudoers ALL=(ALL) ALL, !>

    Tree generated so far:
    

Syntax error in lens definition
Failed to load /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
```
It turns out that these messages actually indicated that my *tests* were bad,
not the changes I'd made to the lense file.

## Final fix
Once I'd recogised this (which I was able to prove by using augtool with the
fixed lens), I set about fixing up my tests.  Eventaully I managed to fix them 
and the tets passed.  You can tell your tests are passing when `augparse` gives 
no output.

The things I had to do to correct my testfiles were:
* Understand that there are typically two parts to a test: Running it and then 
  doing an _exact_ parse tree comparison to make sure everything is matching
  correctl
* Comments and whitespace will normally show up in the parse-tree so you have
  to take care to match them exactly
* Ensure the line is ended with a `\n` sequence.

Hopefully this fix can be merged upstream soon.  If your intersted in a closer look
look at how the code mentioned one this page works, please see https://github.com/hercules-team/augeas/pull/26



