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

  def ticket_message(id)
    t = ticket(id)
    "#{t[:summary]} (#{t[:link]})"
  end

  def user(name)
    if tickets = @users[name]
      tickets.map { |t| ticket_message(t[:id]) }
    else
      ["You don't have any tickets assigned."]
    end
  end

  def marked_for_review
    result = []
    @active_tickets.each { |id, t| result << id if t[:marked_for_review] }
    if result.empty?
      ["There are currently no open tickets marked for review."]
    else
      result.sort.map { |id| ticket_message(id) }
    end
  end

  # Returns a ticket that nobody is working on yet, in ascending order.
  def open_ticket
    ot = nil
    @active_tickets.keys.sort.each do |id|
      t = ticket(id)
      unless t[:assigned_to]
        ot = t
        break
      end
    end
    if ot
      "Ticket available #{ticket_message(ot[:id])}"
    else
      "There are no more open tickets! \o/"
    end
  end

  def assign_ticket(id, user)
    t = ticket(id)
    if assigned_to = t[:assigned_to]
      if assigned_to == user
        "Ticket ##{id} is already assigned to `#{user}'."
      else
        "Ticket ##{id} can't be assigned to `#{user}', as it is already assigned to `#{assigned_to}'."
      end
    else
      t[:assigned_to] = user
      @users[user] ||= []
      @users[user] << t
      @users[user] = @users[user].sort_by { |x| x[:id] }
      "Ticket ##{id} is now assigned to `#{user}'."
    end
  end

  def resign_from_ticket(id, user)
    t = ticket(id)
    if assigned_to = t[:assigned_to]
      if assigned_to == user
        t[:assigned_to] = nil
        "Ticket ##{id} was resigned by `#{user}'."
      else
        "Ticket #19 can't be unassigned by `#{user}', as it is assigned to `#{assigned_to}'."
      end
    else
      "Ticket ##{id} is already unassigned."
    end
  end

  def ticket_status(id)
    t = ticket(id)
    if user = t[:assigned_to]
      "Ticket ##{id} is assigned to `#{user}'#{ ' and marked for review' if t[:marked_for_review] }."
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
      "Ticket ##{id} can't be marked for review by `#{user}', as it is assigned to `#{assigned_to}'."
    else
      "Ticket ##{id} is unassigned."
    end
  end

  def unmark_for_review(id, user)
    t = ticket(id)
    if t[:marked_for_review]
      assigned_to = t[:assigned_to]
      if assigned_to == user
        t[:marked_for_review] = nil
        "Ticket ##{id} is un-marked for review by `#{assigned_to}'."
      else
        "Ticket ##{id} can't be un-marked for review by `#{user}', as it is assigned to `#{assigned_to}'."
      end
    else
      "Ticket ##{id} isn't marked for review."
    end
  end
end
