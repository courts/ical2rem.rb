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

require File.dirname(__FILE__) + '/../ical2rem'
require 'vpim/icalendar'
require 'ostruct'

include Vpim

describe Ical2Rem do

  # Helper method to capture STDOUT, copied from Stefan Kleine Stegemann:
  # http://stefankst.net/2007/06/05/capture-standard-output-in-ruby/
  def with_stdout_captured
    old_stdout = $stdout
    out = StringIO.new
    $stdout = out
    begin
      yield
    ensure
      $stdout = old_stdout
    end
    out.string
  end

  before(:all) do
    options = OpenStruct.new({
      :label => "Calendar",
      :lead => 3,
      :heading => "",
      :todos => true,
      :debug => false
    })
    @obj = Ical2Rem.new
    @obj.instance_variable_set(:@options, options)
  end

  describe "Loading an .ics file" do

    it "should load a vcalendar file when sent #load" do
      cal = @obj.load(File.open(File.dirname(__FILE__) + "/icals/allday_event.ics").read())
      cal.class.should == Vpim::Icalendar
    end

    it "should return an error message and exit when the calendar is not parseable" do
      cal_text = "TEST"
      lambda {@obj.load(cal_text)}.should raise_error(SystemExit)
    end

  end

  describe "Events to remind" do

    before(:all) do
      @cals = [
        "allday_event.ics",
        "timed_event_on_one_day.ics"
      ]
      @cals.map! {|cal| @obj.load(File.open(File.dirname(__FILE__) + "/icals/#{cal}").read())}
    end

    it "should return true if an event's DTSTART value is a DATE-TIME type, false otherwise if sent #dtstart_is_datetime?" do
      @obj.dtstart_is_datetime?(@cals[0].first).should == false
      @obj.dtstart_is_datetime?(@cals[1].first).should == true
    end

    it "should return true if an event's DTSTART and DTEND are on the same day, false otherwise if sent #same_day?" do
      @obj.same_day?(@cals[0].first.dtstart, @cals[0].first.dtend).should == false
      @obj.same_day?(@cals[1].first.dtstart, @cals[1].first.dtend).should == true
    end

    it "should create an untimed remind entry for one day" do
      out = with_stdout_captured do
        @obj.events_to_remind(@cals[0])
      end
      out.to_a[1].should == "REM Jan 1 2006 +3 MSG %a %\"All day event without time%\"%\n"
    end

    it "should create a timed remind entry for one day" do
      out = with_stdout_captured do
        @obj.events_to_remind(@cals[1])
      end
      out.to_a[1].should == "REM Nov 30 2007 AT 08:00 DURATION 2:0 +3 MSG %a %3 %\"One day event with time%\"%\n"
    end

  end

  describe "Todos to remind" do

    before(:all) do
      @cals = [
        "todo_completed.ics",
        "todo_needs_action.ics"
      ]
      @cals.map! {|cal| @obj.load(File.open(File.dirname(__FILE__) + "/icals/#{cal}").read())}
    end

    it "should skip over completed tasks" do
      out = with_stdout_captured do
        @obj.todos_to_remind(@cals[0])
      end
      out.to_a[1].should == nil
    end

    it "should convert an icalendar TODO to remind syntax" do
      out = with_stdout_captured do
        @obj.todos_to_remind(@cals[1])
      end
      out.to_a[1].should == "REM Apr 16 2008 3 1000 MSG %a %\"2008 Test ToDo, needs action%\"%\"%\n"
    end

  end
end
