# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{ical2rem.rb}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Patrick Hof"]
  s.email = %q{courts@offensivethinking.org}
  s.files = [".ical2rem.yaml", "COPYING", "README", "bin/ical2rem-cli", "lib/ical2rem.rb", "test/icals/allday_event.ics", "test/icals/recurrence.ics", "test/icals/timed_event_on_one_day.ics", "test/icals/todo_completed.ics", "test/icals/todo_needs_action.ics", "test/spec_ical2rem.rb"]
  s.homepage = %q{http://www.offensivethinking.org}
  s.require_paths = ["lib"]
  s.executables = ["ical2rem-cli"]
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{ical2rem.rb converts an iCalendar file to Remind syntax}
  s.description = <<-EOT
    ical2rem.rb is based on the Perl program ical2rem.pl by Justin B. 
    Alcorn (http://wiki.43folders.com/index.php/ICal2Rem). It converts an
    iCalendar file's vevent and vtodo components to the
    Remind syntax. You should be able to use it as a drop-in replacement
    for ical2rem.pl with only minor modifications.
  EOT

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<ri_cal>, [">= 0"])
    else
      s.add_dependency(%q<ri_cal>, [">= 0"])
    end
  else
    s.add_dependency(%q<ri_cal>, [">= 0"])
  end
end
