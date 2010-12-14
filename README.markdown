ical2rem.rb
===========

Author:      Patrick Hof <courts@offensivethinking.org>  
Copyright:   Copyright (C) 2008 Patrick Hof  
License:     GPLv3  

Download:    git clone git://github.com/courts/ical2rem.rb.git  
YARD docs:   [http://courts.github.com/ical2rem.rb](http://courts.github.com/ical2rem.rb)

`ical2rem.rb` is based on the Perl program
[`ical2rem.pl`](http://wiki.43folders.com/index.php/ICal2Rem) by Justin B.
Alcorn . It converts an _iCalendar_ file's `VEVENT` and `VTODO` components to
[_Remind_](http://www.roaringpenguin.com/products/remind) syntax. You should be
able to use it as a drop-in replacement for `ical2rem.pl` with only minor
modifications. The command line client which comes with ical2rem.rb is called
`ical2rem-cli` and can be found in the `/bin` directory.

Installation
============

`ical2rem.rb` requires [RiCal](http://ri-cal.rubyforge.org/) You can
install it with RubyGems:

    gem install ri_cal

`ical2rem.rb` itself has a gemspec file, so you can easily build a gem
and install it with:

    gem build ical2rem.rb.gemspec
    gem install ical2rem.rb.-x.x.x.gem

Besides that, no further installation steps are required.  Note that
ical2rem.rb only works with ruby 1.9, not 1.8.


Usage
=====

You can get usage information by running `ical2rem-cli` with the
`-h` switch:

    Usage: ical2rem-cli [options] < input-file [> output-file]
            --label LABEL                Calendar name
            --lead-time LEAD             Advance minutes to start reminders
            --heading HEADING            Define a priority for static entries
        -t, --todos                      Process TODOs?
        -c, --config-file FILE           Use config file FILE (default: .ical2rem.yaml)
        -d, --debug                      Show debug info
        -h, --help                       Show this help

The configuration file (default `.ical2rem.yaml`) further explains the
options you can supply.

`ical2rem-cli` will read any iCalendar file parseable by RiCal from
`STDIN` and print its output to `STDOUT`.


Overview
========

`ical2rem.rb` was mainly written because `ICal::Parser`, the iCal
parsing library `ical2rem.pl` uses, bailed out on my 64bit Ubuntu I was
using at the time. Also, `ical2rem.pl` does not support showing starting
and ending times of events.

The first version used Sam Roberts' vPim, but since it didn't work well with
Ruby 1.9 for some time, I decided to switch to RiCal.

Events
------

`ical2rem.rb` parses iCalendar `VEVENTs` in a similar way to
`ical2rem.pl`, but it will also recognize `TIME-DATE` values in
`DTSTART` and `DTEND` and add them to the output by using remind's
`DURATION` property.

ToDos 
-----

Like `ical2rem.pl`, `ical2rem.rb` also parses iCalendar
`VTODOs`. Unlike `ical2rem.pl`, `ical2rem-cli` will not
parse them by default, parsing has to be enabled with the command line switch
'-t'. At the moment, the same simple approach to parsing as in
`ical2rem.pl` is used. This may improve in future versions.

Bug Reports / Feature Requests / Patches
----------------------------------------

Please send bug reports to my e-mail address given above. Adding 
`[BUG ical2rem.rb]` to the subject will greatly increase your chance of not
getting stuck in my spam filter. The same goes for feature requests, including
`[FEATURE ical2rem.rb]` would be nice.

For patches, please send them as git patches formatted with 
`git-format-patch -n` if possible. Make sure they commit cleanly against
the current `master` branch.

Otherwise, at least include `[PATCH ical2rem.rb]` in your subject.

Thanks
------

*   [Justin B. Alcorn](http://www.jalcorn.net/) for writing `ical2rem.pl`
*   Rick DeNatale for [RiCal](http://ri-cal.rubyforge.org)
*   Sam Roberts for [vPim](http://vpim.rubyforge.org)
