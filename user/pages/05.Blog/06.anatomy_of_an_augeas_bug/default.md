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
XML files and the propper grammar for files it's editing.  It does
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
and from here it only took a couple of seconds to find sudoers lens at `/opt/puppet/share/augeas/lenses/dist/sudoers.aug`.

This is the same file referenced in the customer's error message - I had been
expecting to find a bunch of Ruby files that needed to be fixed but there
weren't any.

## Inside the Lens file
Once I opened the lens file and started looking around even more memories came
flooding back.  This time about [Context-Free Grammars](https://en.wikipedia.org/wiki/Context-free_grammar).  
For the uninitiated, context-free grammars define the rules by which a string
or data structure is parsed and converted into a [parse-tree](https://en.wikipedia.org/wiki/Parse_tree).

They do so by providing a series of [production rules](https://en.wikipedia.org/wiki/Production_%28computer_science%29) that desribe how the entire parsing process in exacting detail.

Basically, this is how you write a language compiler.

Inside the lens file, I saw this code::
```augeas
let lns = ( empty | comment | includedir | alias | defaults | spec )*
```
Which is clearly a the top level entry point into the CFG.

What this line is saying is that the rule `lns` can be rewritten *ONE* of the
following rules:
* `empty`
* `comment`
* `includedir`
* `alias`
* `defaults`
* `spec`

Lets have a look at the simplest one of these rules: `empty`
```augeas
(* View: empty
Map empty lines *)
let empty   = [ del /[ \t]*#?[ \t]*\n/ "\n" ]
```
So far, so good.  This looks like it matches and strips a bunch of whitespace
characters.  Note the newline `\n` at end of the line.  I found out later that
this is vital!  Miss it off and *nothing* will work as the line isn't treated
as finished.

After having a look at some of the other rules, I eventually found the one I was
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

Which splits things up the parse depending on whether we have encountered
an alias or a non alias.  It's hard to see but words containing a capital
can _only_ be matched as aliases because the `non_alias` only matches
lower-case letters.

Looking closely, we can see that the non aliases are allowed to start with an
optional `!` character but the aliases are not (we're missing the `/!?/` bit).

## Now what?
It was time for a bit of research to see how to fix this properly in order to
get the best chance of having a fix accepted upstream.  I found [this](https://stomp.colorado.edu/blog/blog/2011/01/07/on-finding-and-fixing-augeas-parse-errors/) page which was really helpful
and definitely worth a read.

## Writing the testcase
The site above goes into lots of detail about testcases in Augeas.  For this
bug, all I needed to do was edit the file at `/opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug`
and add a new testcase to the bottom of the file.  Running the tests was as simple as typing:
```
augparse /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
```

Once I'd written a testcase which seemed to be doing something by copying the
other examples, I went back in the lens file and started making changes.  The
obvious place was the `sto_to_com_cmnd` rule and I was able to prepend an
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
not the changes I'd made to the lens file.

## Testing
Once I'd recognised this I set about fixing up my tests.  

### Unit testing
Unit testing in Augeas is not like any other unit testing I've seen.  Instead of testing the result of executing a function, your verifying that a correctly labelled parse-tree has been generated.

The parse-tree generated from parsing the input string must *exactly* match 1:1 with the one specified in your test case!  This includes:
* whitespace tokens
* comments
* newlines (`\n`)

The test I developed for this bug looks like this:
```augeas
(* Test: Sudoers.spec
     https://github.com/hercules-team/augeas/issues/262:  Sudoers lens doesn't suppot `!` for command aliases *)
test Sudoers.spec get "%opssudoers ALL=(ALL) ALL, !BANNED\n" =
  { "spec"
    { "user" = "%opssudoers" }
    { "host_group"
      { "host" = "ALL" }
      { "command" = "ALL"
        { "runas_user" = "ALL" } }
      { "command" = "!BANNED" }
    }
  }
```

Briefly, this code code performs a partial parse on the input string using the `Sudoer.spec` rule that we looked at earlier.

After the equals sign, we describe the *exact* partial parse tree - partial because we are only parsing against with the spec rule, not the whole file rule.

Once I was able to match the generated tree with the testcase tree, the tests passed.  You can tell your tests are passing when `augparse` gives no output, like this:

```shell
[root@master vagrant]# /opt/puppet/bin/augparse /opt/puppet/share/augeas/lenses/dist/tests/test_sudoers.aug
[root@master vagrant]#
```

The things I had to do to correct my testfiles were:
* Understand that there are typically two parts to a test: Running it and then
  doing an _exact_ parse tree comparison to make sure everything is matching
  correctly
* Comments and whitespace will normally show up in the parse-tree so you have
  to take care to match them exactly
* Ensure the line is ended with a `\n` sequence.

With unit tests passing, it was time to perform whole-system testing to make
sure that the lens was indeed correctly working.

#### Test the parse tree
To test that a valid parse-tree was produced outside of the testcase, I used `augtool` with it's `ls`
command.  This printed out pages of data with no visible errors:
```shell
[root@master augeas_sudo_hotfix]# /opt/puppet/bin/augtool ls /files/etc/sudoers
#comment[1] = # Sudoers allows particular users to run various commands as
#comment[2] = # the root user, without needing the root password.
#comment[3] = #
#comment[4] = # Examples are provided at the bottom of the file for collections
#comment[5] = # of related commands, which can then be delegated out to particular
#comment[6] = # users or groups.
...
```

#### Double check for error messages
Just to make sure I hadn't missed any error messages in the pages of text from
the parse-tree, I ran the following command to check for errors:
```shell
[root@master vagrant]# /opt/puppet/bin/augtool print /augeas//error
[root@master vagrant]#
```

#### Test file updating
The final part of testing was to ensure that I was now able to write a negated
command alias in the `/etc/sudoers` file.

This is really easy using `augtool` so all I had to do was run:
```shell
[root@master ~]# augtool
augtool> set /files/etc/sudoers/spec[2]/host_group/command[3] !NETWORKING
save
Saved 1 file(s)
augtool> quit
[root@master ~]#
```
The numbers in square brackets indicate the position in the parse-tree being
added or edited and your able to use `tab` to complete the parse-tree paths
as you type them which is hugely helpful.

After checking that the entry was created correctly in `/etc/sudoers`:
```shell
[root@master vagrant]# grep \!NET /etc/sudoers
%sportshorseracingopssudoers ALL=(ALL) ALL, !ADMIN_CMDS , !NETWORKING
```

I was happy that this code was ready for release by creating a GitHub Pull
Request.



## Resolution
Hopefully this fix can be merged upstream soon.  If your interested in a closer look
look at the code that was produced, please see https://github.com/hercules-team/augeas/pull/26
