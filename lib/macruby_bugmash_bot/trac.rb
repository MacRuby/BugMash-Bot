# RSS: http://www.macruby.org/trac/query?status=new&status=reopened&format=rss&col=id&col=summary&col=status&col=time&order=priority&max=1000

$:.unshift File.expand_path("../../../vendor/simple-rss/lib", __FILE__)
require "simple-rss"
require "cgi"

module Trac
  def self.raw_active_tickets_feed
    # TODO
  end

  def self.active_tickets
    rss = SimpleRSS.parse(raw_active_tickets_feed)
    result = rss.entries.inject({}) do |h, entry|
      id = File.basename(entry[:link]).to_i
      h[id] = { :link => entry[:link], :summary => CGI.unescapeHTML(entry[:title]) }
      h
    end
    result
  end
end
