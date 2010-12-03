$:.unshift File.expand_path("../../../vendor/simple-rss/lib", __FILE__)
require "simple-rss"
require "cgi"

class Trac
  # RSS feed: http://www.macruby.org/trac/query?status=new&status=reopened&format=rss&col=id&col=summary&col=status&col=time&order=priority&max=1000
  def self.raw_active_tickets_feed
    # TODO
  end

  def active_tickets
    @active_tickets ||= begin
      rss = SimpleRSS.parse(self.class.raw_active_tickets_feed)
      result = rss.entries.inject({}) do |h, entry|
        id = File.basename(entry[:link]).to_i
        h[id] = { :id => id, :link => entry[:link], :summary => CGI.unescapeHTML(entry[:title]) }
        h
      end
      result
    end
  end

  # Returns a ticket that nobody is working on yet, in ascending order.
  def open_ticket
    id = active_tickets.keys.sort.first
    active_tickets[id]
  end
end
