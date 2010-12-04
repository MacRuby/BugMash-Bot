# encoding: UTF-8

$:.unshift File.expand_path("../../../vendor/simple-rss/lib", __FILE__)
require "simple-rss"
require "net/http"
require "cgi"

require "rubygems"
require "sequel"

class DB
  def self.db_path
    db = File.expand_path('../../../data/db.sqlite3', __FILE__)
  end

  def self.connection
    @db ||= Sequel.sqlite(db_path)
  end

  def self.create!
    connection.create_table :users do
      primary_key :id
      String :name
    end
    connection.create_table :tickets do
      Integer :id, :primary_key => true
      String :link
      String :summary, :text => true
      Integer :assigned_to
      FalseClass :marked_for_review
      FalseClass :closed
    end
  end

  def self.tickets
    connection[:tickets]
  end

  def self.ticket(id)
    tickets.filter(:id => id, :closed => false).first
  end

  def self.users
    connection[:users]
  end

  def self.user(id)
    users.filter(:id => id).first
  end

  def self.find_or_insert_user(name)
    if user = users.filter(:name => name).first
      user[:id]
    else
      users.insert(:name => name)
    end
  end

  def self.user_tickets(name)
    if user = users.filter(:name => name).first
      tickets.filter(:assigned_to => user[:id], :closed => false).all
    end
  end

  def self.ticket_user(id)
    if x = ticket(id)
      user(x[:assigned_to])
    end
  end

  def self.tickets_marked_for_review
    tickets.filter(:marked_for_review => true, :closed => false).order(:id).all
  end

  def self.random_open_ticket
    t = tickets.filter(:assigned_to => nil).all
    unless t.empty?
      index = rand(t.size)
      t[index]
    end
  end

  OPEN_TICKETS_RSS_FEED = URI.parse("http://www.macruby.org/trac/query?status=new&status=reopened&max=1000&format=rss&order=priority&col=id&col=summary&col=status&col=time&milestone=%21MacRuby+1.0&milestone=%21MacRuby+Later")

  def self.raw_open_tickets_feed
    Net::HTTP.get(OPEN_TICKETS_RSS_FEED)
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
      open_ids = tickets.filter(:closed => false).select(:id).all.map { |t| t[:id] }
      seen = []

      rss.entries.each do |entry|
        id = File.basename(entry[:link]).to_i
        seen << id
        if tickets.filter(:id => id).first
          tickets.filter(:id => id).update(:closed => false)
        else
          tickets.insert(:id => id, :link => entry[:link], :summary => CGI.unescapeHTML(entry[:title]), :marked_for_review => false, :closed => false)
        end
      end

      closed = open_ids - seen
      #p closed

      closed.each do |id|
        tickets.filter(:id => id).update(:closed => true)
      end
    end
  end
end
