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
    @trac.open_ticket[:id].should == 19
    @trac.open_ticket[:id].should == 19
    @trac.assign_ticket(19, "alloy")
    @trac.open_ticket[:id].should == 47
    @trac.open_ticket[:id].should == 47
    @trac.assign_ticket(47, "alloy")
    @trac.open_ticket[:id].should == 81
    @trac.open_ticket[:id].should == 81
  end

  it "assigns a ticket to a user" do
    @trac.assign_ticket(19, "alloy")
    @trac.ticket(19)[:assigned_to].should == "alloy"

    @trac.assign_ticket(47, "alloy")
    @trac.ticket(47)[:assigned_to].should == "alloy"

    @trac.users["alloy"].should == [@trac.ticket(19), @trac.ticket(47)]
  end

  it "resigns a user from a ticket" do
    @trac.resign_from_ticket(19, "alloy").should == "Ticket #19 was never assigned to `alloy'."
    @trac.assign_ticket(19, "alloy")
    @trac.resign_from_ticket(19, "alloy").should == "Ticket #19 was resigned by `alloy'."
    @trac.ticket(19)[:assigned_to].should == nil
  end

  it "returns the status of a ticket" do
    @trac.ticket_status(19).should == "Ticket #19 is unassigned."
    @trac.assign_ticket(19, "alloy")
    @trac.ticket_status(19).should == "Ticket #19 is assigned to `alloy'."
    @trac.resign_from_ticket(19, "alloy")
    @trac.ticket_status(19).should == "Ticket #19 is unassigned."
  end

  it "marks a ticket to be reviewed" do
    @trac.mark_for_review(19, "alloy").should == "Ticket #19 is unassigned."
    @trac.ticket(19)[:marked_for_review].should == nil

    @trac.assign_ticket(19, "lrz")

    @trac.mark_for_review(19, "alloy").should == "Ticket #19 is assigned to `lrz'."
    @trac.ticket(19)[:marked_for_review].should == nil

    @trac.mark_for_review(19, "lrz").should == "Ticket #19 is marked for review by `lrz'."
    @trac.ticket(19)[:marked_for_review].should == true
  end
end
