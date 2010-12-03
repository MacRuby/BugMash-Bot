# encoding: UTF-8

$:.unshift File.expand_path("../../../vendor/simple-rss/lib", __FILE__)
require "simple-rss"
require "net/http"
require "cgi"

require "rubygems"
require "sequel"

class Ticket
  def self.db_path
    db = File.expand_path('../../data/db.sqlite3', __FILE__)
  end

  def self.connection
    @db ||= Sequel.sqlite(db_path)
  end

  def self.create!
    puts "CREATE #{db_path}"
    connection.create_table :tickets do
      Integer :id, :primary_key => true
      String :link
      String :summary, :text => true
      String :assigned_to
      FalseClass :marked_for_review
      FalseClass :closed
    end
  end

  def self.table
    connection[:tickets]
  end

  OPEN_TICKETS_RSS_FEED = URI.parse("http://www.macruby.org/trac/query?status=new&status=reopened&format=rss&col=id&col=summary&col=status&col=time&order=priority&max=1000")

  def self.raw_open_tickets_feed
    Net::HTTP.get(ACTIVE_TICKETS_RSS_FEED)
  rescue Exception => e
    # obviously this is a bad thing to do, but I really don't want the bot to break this weekend due to HTTP problems...
    puts "[!] FETCHING THE MACRUBY TICKET FEED FAILED DUE TO: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    return nil
  end

  def self.update_open_tickets!
    if raw_feed = raw_open_tickets_feed
      # should not be too bad to force a ASCII string to UTF-8 afaik
      raw_feed.force_encoding('UTF-8') if raw_feed.respond_to?(:force_encoding)

      rss = SimpleRSS.parse(raw_feed)
      open_ids = Ticket.table.filter(:closed => false).select(:id).all.map(&:id)
      seen = []

      rss.entries.each do |entry|
        id = File.basename(entry[:link]).to_i
        seen << id
        unless Ticket.table.filter(:id => id).first
          Ticket.table.insert(:id => id, :link => entry[:link], :summary => CGI.unescapeHTML(entry[:title]), :marked_for_review => false, :closed => false)
        end
      end

      closed = open_ids - seen
      #p closed

      closed.each do |id|
        Ticket.table.filter(:id => id).update(:closed => true)
      end
    end
  end
end
