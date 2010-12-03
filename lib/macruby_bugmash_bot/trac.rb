$:.unshift File.expand_path("../../../vendor/simple-rss/lib", __FILE__)
require "simple-rss"
require "cgi"

class Trac
  # RSS feed: http://www.macruby.org/trac/query?status=new&status=reopened&format=rss&col=id&col=summary&col=status&col=time&order=priority&max=1000
  def self.raw_active_tickets_feed
    # TODO
  end

  attr_reader :active_tickets, :users

  def initialize
    @users = {}
    load_tickets!
  end

  def load_tickets!
    rss = SimpleRSS.parse(self.class.raw_active_tickets_feed)
    @active_tickets = rss.entries.inject({}) do |h, entry|
      id = File.basename(entry[:link]).to_i
      h[id] = { :id => id, :link => entry[:link], :summary => CGI.unescapeHTML(entry[:title]) }
      h
    end
  end

  def ticket(id)
    @active_tickets[id]
  end

  # Returns a ticket that nobody is working on yet, in ascending order.
  def open_ticket
    id = @active_tickets.keys.sort.first
    @active_tickets[id]
  end

  def assign_ticket(id, user)
    @users[user] ||= []
    t = ticket(id)
    t[:assigned_to] = user
    @users[user] << t
  end
end
