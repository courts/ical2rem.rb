#!/usr/bin/env ruby
 
# Copyright (C) 2008 Patrick Hof
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'vpim/icalendar'
require 'optparse'
require 'ostruct'
require 'time'
require 'yaml'

include Vpim

# Main class in <tt>ical2rem.rb</tt>, will get initialized if it is run from the
# command line.
class Ical2Rem

  # Start the conversion by parsing the command line options and running the
  # events_to_remind and possibly the todos_to_remind methods.
  def run
    @options = parseopts(ARGV)
    @debug = @options.debug
    p @options if @debug
    cal = load($stdin.read())
    if @options.todos
      todos_to_remind(cal)
    end
    events_to_remind(cal)
  end


  # Parses the command line options and returns an +OpenStruct+ options object.
  def parseopts(args)
    default_opts = {
      :label => "",
      :lead => 3,
      :heading => "",
      :todos => false,
      :dtend_rfc => false,
      :debug => false,
      :config => ".ical2rem.yaml"
    }
    cl_opts = {}
    opts = OptionParser.new do |opts|
      opts.banner = "Usage: #{__FILE__} [options] < input-file [> output-file]"
      opts.separator ""
      opts.on("--label LABEL", "Calendar name") do |label|
        cl_opts[:label] = label
      end
      opts.on("--lead-time LEAD", "Advance days to start reminders") do |lead|
        cl_opts[:lead] = lead
      end
      opts.on("-t", "--todos", "Process TODOs?") do
        cl_opts[:todos] = true
      end
      opts.on("--heading HEADING", "Define a priority for static entries") do |heading|
        cl_opts[:heading] = heading
      end
      opts.on("-t", "--todos", "Process TODOs?") do
        cl_opts[:todos] = true
      end
      opts.on("-c", "--config-file FILE", "Use config file FILE (default: #{default_opts[:config]})") do |config|
        cl_opts[:config] = config
      end
      opts.on("-d", "--debug", "Show debug info") do
        cl_opts[:debug] = true
      end
      opts.on("-h", "--help", "Show this help") do
        puts opts
        exit
      end
    end
    opts.parse!
    # Load options from config file
    if cl_opts[:config]
      configfile_opts = YAML.load(File.open(cl_opts[:config]))
    else
      configfile_opts = YAML.load(File.open(default_opts[:config]))
    end
    # Check if the config file was empty
    if configfile_opts
      options = default_opts.update(configfile_opts)
    else
      options = default_opts
    end
    options = options.update(cl_opts)
    options = OpenStruct.new(options)
    options
  end

  # Takes a string +cal_text+ as parameter and returns a
  # <tt>Vpim::Icalendar</tt> object if the string could be loaded successfully.
  # Will abort the program otherwise.
  def load(cal_text)
    begin
      Icalendar.decode(cal_text).first
    rescue InvalidEncodingError => e
      $stderr.write "Could not parse ICalendar, aborting.\n"
      exit 1
    end
  end


  # Checks if the event +event+ has a DATE-TIME +DTSTART+ value instead of DATE
  # (e.g. <em>20081112T070000Z</em> instead of <em>20081112</em>).  If this is the case, it
  # returns +true+, otherwise, it returns +false+.
  #
  # +DTEND+ does not need to be checked as per RFC, if +DTSTART+ is only a DATE
  # value, +DTEND+ _must_ be a DATE value, too. So if +DTEND+ has any time
  # given, it is ignored.
  def dtstart_is_datetime?(event)
    if event.properties.field("DTSTART").value =~ /^\d{8}$/
      return false
    else
      return true 
    end
  end


  # Check if two <tt>Time</tt> objects +vstart+ and +vend+ have the same date. Returns
  # either +true+ or +false+.
  def same_day?(vstart, vend)
    if vstart.year < vend.year || vstart.month < vend.month || vstart.day < vend.day
      return false
    else
      return true
    end
  end


  # Converts the events of _ICalendar_ +cal+ to _Remind_ syntax, writing it to +STDOUT+.
  def events_to_remind(cal)

    # The heading of the calendar file, e.g.
    # REM MSG Calendar Events:%"%"%
    if not @options.heading.empty? or not @options.label.empty?
      puts "REM #{@options.heading} MSG #{@options.label} Events:%\"%\"%"
    end

    # Now, produce an entry for every event in the calendar
    cal.events do |event|
      vstart = event.dtstart.getlocal
      vend = event.dtend.getlocal

      # The starting date, e.g.
      # REM Jan 01 2008
      print "REM #{vstart.strftime("%b")} #{vstart.day} #{vstart.year}"

      # Check if we need to print an ending date with UNTIL.
      # We print an UNTIL if:
      # - The starting and ending date are different AND
      #   - Either starting and ending are DATE-TIME objects OR
      #   - The end date is not the start date plus one. We do this by simply
      #     checking if the duration is bigger than 24 hours. 
      #
      # The latter is due to the fact that in the Icalendar RFC 2445 the DTEND
      # value of a VEVENT is specified to be non-inclusive. Most .ics file
      # producing calendars interpret this as meaning that if we want to have an
      # all-day event on e.g.  Jan 1st 2008, we need to write this as
      #
      # DTSTART:20080101
      # DTEND:20080102
      #
      # There is a controversy if this interpretation is right, see e.g. 
      #
      # http://www.bedework.org/trac/bedework/wiki/Bedework/DevDocs/DtstartEndNotes
      is_datetime = dtstart_is_datetime?(event)
      if not same_day?(vstart, vend) and (is_datetime or (event.duration > 86400))
        print " UNTIL #{vend.strftime("%b")} #{vend.day} #{vend.year} *1"
      end

      # If +DTSTART+ is a DATE-TIME value, add an AT clause, e.g.
      # AT 10:00 DURATION 2:0
      if is_datetime
        print " AT #{vstart.strftime("%H:%M")}"
        print " DURATION #{event.duration / 3600}:#{(event.duration % 3600) / 60}"
      end

      # The advance days to show this entry, e.g.
      # +3
      print " +#{@options.lead}"

      # The message of the event. If +DTSTART+ is a DATE-TIME object, the
      # starting time is also printed by inserting the variable "%3".
      print " MSG %a"
      if is_datetime
        print " %3"
      end
      print " %\"#{event.summary}" 

      # If a location for the event is given, we add it to the message.
      print " at #{event.location}" if event.location
      puts "\%\"%"
    end
  end

  # Converts the todos of _ICalendar_ +cal+ to _Remind_ syntax, writing it to +STDOUT+.
  def todos_to_remind(cal)

    # The heading of the calendar file, e.g.
    # REM MSG Calendar Events:%"%"%
    if not @options.heading.empty? or not @options.label.empty?
      puts "REM #{@options.heading} MSG #{@options.label} ToDos:%\"%\"%"
    end

    cal.todos do |todo|
      # Check for the task already being completed and skip it if true
      if todo.status and todo.status == "COMPLETED"
        next
      else
        # The due time is either set in the +todo+ with the +DUE+ value or set
        # to +DTSTART+. If both do not exist, set +due+ to now.
        due = Time.now
        if todo.due
          due = todo.due.getlocal
        elsif todo.dtstart
          due = todo.dtstart.getlocal
        end
        # If a priority is given (in icalendar syntax from 1-9), convert it to
        # remind syntax (0 - 9999).
        priority = ""
        if todo.priority
          priority = (todo.priority * 1000).to_s
        end
        # Lead time is the duration of the task plus the default lead time.
        lead = @options.lead
        if todo.dtstart and todo.due
          dt_start = DateTime.parse(todo.dtstart.to_s)
          dt_due = DateTime.parse(todo.due.to_s)
          diff = (dt_due - dt_start).to_i
          lead = diff + @options.lead
        end
        puts "REM #{due.strftime("%b")} #{due.day} #{due.year} #{lead} #{priority} MSG \%a %\"#{todo.summary}\%\"\%\"\%"
      end
    end
  end

end


if __FILE__ == $0
  Ical2Rem.new.run
end
