require "rubygems"
require "bacon"
Bacon.summary_at_exit

$:.unshift File.expand_path("../../lib", __FILE__)
require "macruby_bugmash_bot/trac"

FIXTURE_ROOT = File.expand_path("../fixtures", __FILE__)
def fixture(name)
  File.join(FIXTURE_ROOT, name)
end
def fixture_read(name)
  File.read(fixture(name))
end

class Trac
  def self.raw_active_tickets_feed
    fixture_read("trac_active_tickets_rss.xml")
  end
end

describe "Trac" do
  before do
    @trac = Trac.new
  end

  it "parses the raw RSS feed" do
    @trac.active_tickets[189][:id].should == 189
    @trac.active_tickets[189][:summary].should == "#189: Bugs with: Class#dup & Object#dup"
    @trac.active_tickets[105][:id].should == 105
    @trac.active_tickets[105][:summary].should == "#105: BridgeSupport can't convert KCGSessionEventTap as an argument for CGEventTapCreate"
  end

  it "returns a ticket by ID" do
    @trac.ticket(189)[:id].should == 189
    @trac.ticket(189)[:summary].should == "#189: Bugs with: Class#dup & Object#dup"
    @trac.ticket(105)[:id].should == 105
    @trac.ticket(105)[:summary].should == "#105: BridgeSupport can't convert KCGSessionEventTap as an argument for CGEventTapCreate"
  end

  it "returns a ticket that nobody is working on yet, in ascending ID order" do
    @trac.open_ticket.should == "Ticket available #19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)"
    @trac.open_ticket.should == "Ticket available #19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)"
    @trac.assign_ticket(19, "alloy")
    @trac.open_ticket.should == "Ticket available #47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"
    @trac.open_ticket.should == "Ticket available #47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"
    @trac.assign_ticket(47, "alloy")
    @trac.open_ticket.should == "Ticket available #81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"
    @trac.open_ticket.should == "Ticket available #81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"

    @trac.active_tickets.each { |_, t| t[:assigned_to] = "alloy" }
    @trac.open_ticket.should == "There are no more open tickets! \o/"
  end

  it "assigns a ticket to a user" do
    @trac.assign_ticket(19, "alloy").should == "Ticket #19 is now assigned to `alloy'."
    @trac.ticket(19)[:assigned_to].should == "alloy"

    @trac.assign_ticket(47, "alloy").should == "Ticket #47 is now assigned to `alloy'."
    @trac.ticket(47)[:assigned_to].should == "alloy"

    @trac.users["alloy"].should == [@trac.ticket(19), @trac.ticket(47)]

    @trac.assign_ticket(19, "lrz").should == "Ticket #19 can't be assigned to `lrz', as it is already assigned to `alloy'."
    @trac.assign_ticket(19, "alloy").should == "Ticket #19 is already assigned to `alloy'."
  end

  it "resigns a user from a ticket" do
    @trac.resign_from_ticket(19, "alloy").should == "Ticket #19 is already unassigned."
    @trac.assign_ticket(19, "alloy")
    @trac.resign_from_ticket(19, "lrz").should == "Ticket #19 can't be unassigned by `lrz', as it is assigned to `alloy'."
    @trac.resign_from_ticket(19, "alloy").should == "Ticket #19 was resigned by `alloy'."
    @trac.ticket(19)[:assigned_to].should == nil
  end

  it "returns the status of a ticket" do
    @trac.ticket_status(19).should == "Ticket #19 is unassigned."
    @trac.assign_ticket(19, "alloy")
    @trac.ticket_status(19).should == "Ticket #19 is assigned to `alloy'."
    @trac.mark_for_review(19, "alloy")
    @trac.ticket_status(19).should == "Ticket #19 is assigned to `alloy' and marked for review."
    @trac.resign_from_ticket(19, "alloy")
    @trac.ticket_status(19).should == "Ticket #19 is unassigned."
  end

  it "marks a ticket to be reviewed" do
    @trac.mark_for_review(19, "alloy").should == "Ticket #19 is unassigned."
    @trac.ticket(19)[:marked_for_review].should == nil

    @trac.assign_ticket(19, "lrz")

    @trac.mark_for_review(19, "alloy").should == "Ticket #19 can't be marked for review by `alloy', as it is assigned to `lrz'."
    @trac.ticket(19)[:marked_for_review].should == nil

    @trac.mark_for_review(19, "lrz").should == "Ticket #19 is marked for review by `lrz'."
    @trac.ticket(19)[:marked_for_review].should == true
  end

  it "unmarks a ticket to be reviewed" do
    @trac.unmark_for_review(19, "alloy").should == "Ticket #19 isn't marked for review."
    @trac.ticket(19)[:marked_for_review].should == nil

    @trac.assign_ticket(19, "lrz")
    @trac.mark_for_review(19, "lrz")

    @trac.unmark_for_review(19, "alloy").should == "Ticket #19 can't be un-marked for review by `alloy', as it is assigned to `lrz'."
    @trac.ticket(19)[:marked_for_review].should == true

    @trac.unmark_for_review(19, "lrz").should == "Ticket #19 is un-marked for review by `lrz'."
    @trac.ticket(19)[:marked_for_review].should == nil
  end

  it "returns a list of messages about tickets the user is working on, sorted by ID" do
    @trac.user("lrz").should == ["You don't have any tickets assigned."]
    @trac.user("alloy").should == ["You don't have any tickets assigned."]
    @trac.assign_ticket(81, "alloy")
    @trac.assign_ticket(47, "lrz")
    @trac.assign_ticket(19, "alloy")
    @trac.user("lrz").should == ["#47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)"]
    @trac.user("alloy").should == ["#19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)", "#81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"]
  end

  it "returns a list of tickets that are marked for review" do
    @trac.marked_for_review.should == ["There are currently no open tickets marked for review."]
    @trac.assign_ticket(81, "alloy")
    @trac.mark_for_review(81, "alloy")
    @trac.assign_ticket(47, "lrz")
    @trac.mark_for_review(47, "lrz")
    @trac.assign_ticket(19, "alloy")
    @trac.mark_for_review(19, "alloy")
    @trac.marked_for_review.should == ["#19: Problems with method_missing (http://www.macruby.org/trac/ticket/19)", "#47: Cannot pass a :symbol directly as a named parameter (http://www.macruby.org/trac/ticket/47)", "#81: Enumerable::Enumerator seems to be broken (http://www.macruby.org/trac/ticket/81)"]
  end
end
