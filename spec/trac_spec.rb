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
  end

  it "assigns a ticket to a user" do
    @trac.assign_ticket(19, "alloy")
    @trac.ticket(19)[:assigned_to].should == "alloy"

    @trac.assign_ticket(47, "alloy")
    @trac.ticket(47)[:assigned_to].should == "alloy"

    @trac.users["alloy"].should == [@trac.ticket(19), @trac.ticket(47)]
  end
end
