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

module Trac
  def self.raw_active_tickets_feed
    fixture_read("trac_active_tickets_rss.xml")
  end
end

describe "Trac" do
  it "creates a hash out of the raw RSS feed" do
    Trac.active_tickets[189][:summary].should == "Bugs with: Class#dup & Object#dup"
  end
end