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
    @active_tickets.keys.sort.each do |id|
      t = ticket(id)
      break t unless t[:assigned_to]
    end
  end

  def assign_ticket(id, user)
    @users[user] ||= []
    t = ticket(id)
    t[:assigned_to] = user
    @users[user] << t
  end

  def resign_from_ticket(id, user)
    t = ticket(id)
    if t[:assigned_to] == user
      t[:assigned_to] = nil
      "Ticket ##{id} was resigned by `#{user}'."
    else
      "Ticket ##{id} was never assigned to `#{user}'."
    end
  end

  def ticket_status(id)
    t = ticket(id)
    if user = t[:assigned_to]
      "Ticket ##{id} is assigned to `#{user}'."
    else
      "Ticket ##{id} is unassigned."
    end
  end

  def mark_for_review(id, user)
    t = ticket(id)
    assigned_to = t[:assigned_to]
    if assigned_to == user
      t[:marked_for_review] = true
      "Ticket ##{id} is marked for review by `#{assigned_to}'."
    elsif !assigned_to.nil?
      "Ticket ##{id} is assigned to `#{assigned_to}'."
    else
      "Ticket ##{id} is unassigned."
    end
  end
end
