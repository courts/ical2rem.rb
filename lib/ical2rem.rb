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

require 'ri_cal'
require 'optparse'
require 'ostruct'
require 'time'
require 'yaml'

include RiCal

# ical2rem.rb converts an _iCalendar_ file's VEVENT and VTODO components to
# Remind syntax.
#
# @author Patrick Hof
class Ical2Rem

  # Start the conversion by parsing the command line options and running the
  # events_to_remind() and possibly the todos_to_remind() methods.
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


  # Parses the command line options.
  #
  # @param [Array] args the command line arguments
  # @return [OpenStruct] an options object
  def parseopts(args)
    default_opts = {
      :label => "",
      :lead => 3,
      :heading => "",
      :todos => false,
      :dtend_rfc => false,
      :debug => false,
      :config => File.expand_path(File.join(File.dirname(__FILE__), '..', '.ical2rem.yaml'))
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

  # Load a calendar text. If the text can't be read, the program is aborted.
  #
  # @param [String] cal_text the calendar text
  # @return [Vpim::Icalendar] an Icalendar object if the string was loaded successfully
  def load(cal_text)
    begin
      RiCal.parse_string(cal_text).first
    rescue InvalidEncodingError => e
      $stderr.write "Could not parse ICalendar, aborting.\n"
      exit 1
    end
  end


  # Check if two Time objects have the same date.
  #
  # @param [Time] vstart The starting time object
  # @param [Time] vend The ending time object
  # @return [Boolean] True if the objects have the same date, False otherwise
  def same_day?(vstart, vend)
    if vstart.year < vend.year || vstart.month < vend.month || vstart.day < vend.day
      return false
    else
      return true
    end
  end

  # Returns the duration of an event.
  #
  # @param [RiCal::Component::Event] event The event to check the duration of
  # @return [Int] Event duration in seconds
  def duration(event)
    return 0 unless event.dtstart and event.dtend
    # XXX Ugly hack to subtract DateTime objects, but it works..
    if event.dtstart.class == DateTime && event.dtend.class == DateTime
      days = (event.dtend.to_date - event.dtstart.to_date).to_i * 24 * 60 * 60
      hours = (event.dtend.to_time - event.dtstart.to_time).to_i
      d = days + hours 
    # Date object subtractions gives us days, so we need to multiply to get
    # seconds
    elsif event.dtstart.class == Date && event.dtend.class == Date
      d = (event.dtend - event.dtstart).to_i * 24 * 60 * 60
    else
      raise "Error. dtstart class: #{event.dtstart.class}, dtend class: #{event.dtend.class}"
    end
    # Check for a negative duration, which would mean dtstart is after dtend.
    if d >= 0
      return d
    else
      raise "Error: negative duration #{d}"
    end
  end

  # Converts the ICalendar EVENTs Remind syntax, writing everything to STDOUT.
  #
  # @param [RiCal::Component::Calendar] cal the calendar to convert
  def events_to_remind(cal)

    # The heading of the calendar file, e.g.
    # REM MSG Calendar Events:%"%"%
    if not @options.heading.empty? or not @options.label.empty?
      puts "REM #{@options.heading} MSG #{@options.label} Events:%\"%\"%"
    end

    # Now, produce an entry for every event in the calendar
    cal.events.each do |event|
      # XXX Object conversion is expensive, is there no better way?
      vstart = event.dtstart.to_time.getlocal
      vend = event.dtend.to_time.getlocal
      duration = duration(event)

      # The starting date, e.g.
      # REM Jan 01 2008
      print "REM #{vstart.strftime("%b")} #{vstart.day} #{vstart.year}"

      # Check if we need to print an ending date with UNTIL.
      is_datetime = true if event.dtstart.class == DateTime
      if event.bounded? && (event.occurrences.length > 1)
        last = event.occurrences.last.dtend
        if not same_day?(vstart, last)
          print " UNTIL #{last.strftime("%b")} #{last.day} #{vend.year} *1"
        end
      end

      # If +DTSTART+ is a DATE-TIME value, add an AT clause, e.g.
      # AT 10:00 DURATION 2:0
      if is_datetime
        print " AT #{vstart.strftime("%H:%M")}"
        print " DURATION #{duration / 3600}:#{(duration % 3600) / 60}"
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

  # Converts the ICalendar TODOs to Remind syntax, writing everything to STDOUT.
  #
  # @param [RiCal::Component::Calendar] cal the calendar to convert
  def todos_to_remind(cal)

    # The heading of the calendar file, e.g.
    # REM MSG Calendar Events:%"%"%
    if not @options.heading.empty? or not @options.label.empty?
      puts "REM #{@options.heading} MSG #{@options.label} ToDos:%\"%\"%"
    end

    cal.todos.each do |todo|
      # Check for the task already being completed and skip it if true
      if todo.status and todo.status == "COMPLETED"
        next
      else
        # The due time is either set in the +todo+ with the +DUE+ value or set
        # to +DTSTART+. If both do not exist, set +due+ to now.
        due = Time.now
        if todo.due
          due = todo.due.to_time.getlocal
        elsif todo.dtstart
          due = todo.dtstart.to_time.getlocal
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
