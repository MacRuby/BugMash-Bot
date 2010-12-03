require "rubygems"
require "bacon"
Bacon.summary_at_exit

require "fileutils"

$:.unshift File.expand_path("../../lib", __FILE__)
require "macruby_bugmash_bot/trac"

FIXTURE_ROOT = File.expand_path("../fixtures", __FILE__)
def fixture(name)
  File.join(FIXTURE_ROOT, name)
end
def fixture_read(name)
  File.read(fixture(name))
end

class DB
  def self.db_path
    @db_path ||= "/tmp/bugmash-bot-test-#{Time.now.to_i}.sqlite3"
  end

  def self.stubbed_feed=(xml)
    @stubbed_feed = xml
  end

  def self.raw_open_tickets_feed
    @stubbed_feed
  end
end

DB.create!

describe "Trac" do
  before do
    DB.tickets.delete
    DB.users.delete
    DB.stubbed_feed = fixture_read("trac_active_tickets_rss.xml")
    DB.update_open_tickets!
    @trac = Trac.new
  end

  it "returns a ticket by ID" do
    @trac.ticket(189)[:id].should == 189
    @trac.ticket(189)[:summary].should == "#189: Bugs with: Class#dup & Object#dup"
    @trac.ticket(105)[:id].should == 105
    @trac.ticket(105)[:summary].should == "#105: BridgeSupport can't convert KCGSessionEventTap as an argument for CGEventTapCreate"
  end

  # Make random
  #it "returns a ticket that nobody is working on yet, in ascending ID order" do
    #@trac.open_ticket.should == "Ticket available #19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)"
    #@trac.open_ticket.should == "Ticket available #19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)"
    #@trac.assign_ticket(19, "alloy")
    #@trac.open_ticket.should == "Ticket available #47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"
    #@trac.open_ticket.should == "Ticket available #47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"
    #@trac.assign_ticket("47", "alloy")
    #@trac.open_ticket.should == "Ticket available #81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"
    #@trac.open_ticket.should == "Ticket available #81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"

    #@trac.active_tickets.each { |_, t| t[:assigned_to] = "alloy" }
    #@trac.open_ticket.should == "There are no more open tickets! \o/"
  #end

  it "assigns a ticket to a user" do
    @trac.assign_ticket("19", "alloy").should == "Ticket #19 is now assigned to `alloy'."
    DB.ticket_user(19)[:name].should == "alloy"

    @trac.assign_ticket(47, "alloy").should == "Ticket #47 is now assigned to `alloy'."
    DB.ticket_user(47)[:name].should == "alloy"

    DB.user_tickets("alloy").should == [@trac.ticket(19), @trac.ticket(47)]

    @trac.assign_ticket(19, "lrz").should == "Ticket #19 can't be assigned to `lrz', as it is already assigned to `alloy'."
    @trac.assign_ticket(19, "alloy").should == "Ticket #19 is already assigned to `alloy'."
  end

  it "resigns a user from a ticket" do
    @trac.resign_from_ticket(19, "alloy").should == "Ticket #19 is already unassigned."
    @trac.assign_ticket(19, "alloy")
    @trac.resign_from_ticket(19, "lrz").should == "Ticket #19 can't be unassigned by `lrz', as it is assigned to `alloy'."
    @trac.resign_from_ticket("19", "alloy").should == "Ticket #19 was resigned by `alloy'."
    DB.ticket_user(19).should == nil
  end

  it "returns the status of a ticket" do
    @trac.ticket_status(19, "alloy").should == "Ticket #19 is unassigned."
    @trac.assign_ticket(19, "alloy")
    @trac.ticket_status("19", "alloy").should == "Ticket #19 is assigned to `alloy'."
    @trac.mark_for_review(19, "alloy")
    @trac.ticket_status(19, "alloy").should == "Ticket #19 is assigned to `alloy' and marked for review."
    @trac.resign_from_ticket(19, "alloy")
    @trac.ticket_status(19, "alloy").should == "Ticket #19 is unassigned."
  end

  it "marks a ticket to be reviewed" do
    @trac.mark_for_review(19, "alloy").should == "Ticket #19 is unassigned."
    @trac.ticket(19)[:marked_for_review].should == false

    @trac.assign_ticket(19, "lrz")

    @trac.mark_for_review(19, "alloy").should == "Ticket #19 can't be marked for review by `alloy', as it is assigned to `lrz'."
    @trac.ticket(19)[:marked_for_review].should == false

    @trac.mark_for_review("19", "lrz").should == "Ticket #19 is marked for review by `lrz'."
    @trac.ticket(19)[:marked_for_review].should == true
  end

  it "unmarks a ticket to be reviewed" do
    @trac.unmark_for_review(19, "alloy").should == "Ticket #19 isn't marked for review."
    @trac.ticket(19)[:marked_for_review].should == false

    @trac.assign_ticket(19, "lrz")
    @trac.mark_for_review(19, "lrz")

    @trac.unmark_for_review(19, "alloy").should == "Ticket #19 can't be unmarked for review by `alloy', as it is assigned to `lrz'."
    @trac.ticket(19)[:marked_for_review].should == true

    @trac.unmark_for_review("19", "lrz").should == "Ticket #19 is unmarked for review by `lrz'."
    @trac.ticket(19)[:marked_for_review].should == false
  end

  it "returns a list of messages about tickets the user is working on, sorted by ID" do
    @trac.user("lrz").should == ["You don't have any tickets assigned."]
    @trac.user("alloy").should == ["You don't have any tickets assigned."]
    @trac.assign_ticket(81, "alloy")
    @trac.assign_ticket(47, "lrz")
    @trac.assign_ticket(19, "alloy")
    @trac.user("lrz").should == ["You are currently working on 1 ticket:", "#47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"]
    @trac.user("alloy").should == ["You are currently working on 2 tickets:", "#19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)", "#81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"]
  end

  it "returns a list of tickets that are marked for review" do
    @trac.marked_for_review.should == ["There are currently no open tickets marked for review."]
    @trac.assign_ticket(81, "alloy")
    @trac.mark_for_review(81, "alloy")
    @trac.assign_ticket(47, "lrz")
    @trac.mark_for_review(47, "lrz")
    @trac.assign_ticket(19, "alloy")
    @trac.mark_for_review(19, "alloy")
    @trac.marked_for_review.should == ["There are currently 3 tickets marked for review:", "#19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)", "#47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)", "#81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"]
  end

  it "returns a good message when a ticket is not open (anymore)" do
    @trac.ticket_status(123456789, "alloy").should == "Ticket #123456789 is not an open ticket (anymore)."
    @trac.assign_ticket(123456789, "alloy").should == "Ticket #123456789 is not an open ticket (anymore)."
    @trac.resign_from_ticket(123456789, "alloy").should == "Ticket #123456789 is not an open ticket (anymore)."
    @trac.mark_for_review(123456789, "alloy").should == "Ticket #123456789 is not an open ticket (anymore)."
    @trac.unmark_for_review(123456789, "alloy").should == "Ticket #123456789 is not an open ticket (anymore)."
  end
end

#describe "Trac, after an update of the active tickets feed" do
  #before do
    #Trac.stubbed_feed = fixture_read("trac_active_tickets_rss.xml")
    #@trac = Trac.new
    #@trac.assign_ticket(81, "alloy")
    #@trac.mark_for_review(81, "alloy")
    #@trac.assign_ticket(47, "lrz")
    #@trac.mark_for_review(47, "lrz")
    #@trac.assign_ticket(19, "alloy")

    #Trac.stubbed_feed = fixture_read("trac_active_tickets_rss-minus-19-and-81.xml")
    #@trac.load_tickets!
  #end

  #it "no longer gives a status for a ticket that's not in the active-tickets feed anymore" do
    #@trac.ticket_status(19, "alloy").should == "Ticket #19 is not an open ticket (anymore)."
  #end

  #it "no longer lists assigned tickets if they're not in the active-tickets feed anymore" do
    #@trac.user("alloy").should == ["You don't have any tickets assigned."]
    #@trac.user("lrz").should == ["You are currently working on 1 ticket:", "#47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"]
  #end

  #it "no longer lists tickets to be reviewed if they're not in the active-tickets feed anymore" do
    #@trac.marked_for_review.should == ["There is currently 1 ticket marked for review:", "#47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"]
  #end
#end

FileUtils.rm(DB.db_path)
