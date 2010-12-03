$:.unshift File.expand_path("../../../vendor/simple-rss/lib", __FILE__)
require "simple-rss"
require "net/http"
require "cgi"

class Trac
  ACTIVE_TICKETS_RSS_FEED = URI.parse("http://www.macruby.org/trac/query?status=new&status=reopened&format=rss&col=id&col=summary&col=status&col=time&order=priority&max=1000")
  def self.raw_active_tickets_feed
    Net::HTTP.get(ACTIVE_TICKETS_RSS_FEED)
  end

  # Defines an instance method that takes: ID, ticket, user
  # This method, however, is wrapped inside a method that first checks if the
  # ticket is available at all.
  def self.define_ticket_method(name, &block)
    real_method = "_#{name}"
    define_method(real_method, &block)
    private(real_method)
    define_method(name) do |id, user|
      if t = ticket(id)
        send(real_method, id, t, user)
      else
        "Ticket ##{id} is not an open ticket (anymore)."
      end
    end
  end

  attr_reader :active_tickets, :users

  def initialize
    @active_tickets = {}
    @users = {}
    load_tickets!
  end

  def load_tickets!
    rss = nil
    begin
      rss = SimpleRSS.parse(self.class.raw_active_tickets_feed)
      # obviously this is a bad thing to do, but I really don't want the bot to break this weekend due to HTTP problems...
    rescue Exception => e
      puts "[!] FETCHING THE MACRUBY TICKET FEED FAILED DUE TO: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
    end
    if rss
      @active_tickets = rss.entries.inject({}) do |h, entry|
        id = File.basename(entry[:link]).to_i
        h[id] = { :id => id, :link => entry[:link], :summary => CGI.unescapeHTML(entry[:title]) }
        h
      end
      # clean assigned/marked tickets
      @users.each do |name, tickets|
        tickets.reject! { |t| @active_tickets[t[:id]].nil? }
      end
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
    if (tickets = @users[name]) && !tickets.empty?
      tickets.map { |t| ticket_message(t[:id]) }
    else
      ["You don't have any tickets assigned."]
    end
  end

  def marked_for_review
    result = []
    @users.each do |_, tickets|
      tickets.each { |t| result << t[:id] if t[:marked_for_review] }
    end
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

  define_ticket_method :assign_ticket do |id, ticket, user|
    if assigned_to = ticket[:assigned_to]
      if assigned_to == user
        "Ticket ##{id} is already assigned to `#{user}'."
      else
        "Ticket ##{id} can't be assigned to `#{user}', as it is already assigned to `#{assigned_to}'."
      end
    else
      ticket[:assigned_to] = user
      @users[user] ||= []
      @users[user] << ticket
      @users[user] = @users[user].sort_by { |x| x[:id] }
      "Ticket ##{id} is now assigned to `#{user}'."
    end
  end

  define_ticket_method :resign_from_ticket do |id, ticket, user|
    if assigned_to = ticket[:assigned_to]
      if assigned_to == user
        ticket[:assigned_to] = nil
        "Ticket ##{id} was resigned by `#{user}'."
      else
        "Ticket #19 can't be unassigned by `#{user}', as it is assigned to `#{assigned_to}'."
      end
    else
      "Ticket ##{id} is already unassigned."
    end
  end

  define_ticket_method :ticket_status do |id, ticket, _|
    if user = ticket[:assigned_to]
      "Ticket ##{id} is assigned to `#{user}'#{ ' and marked for review' if ticket[:marked_for_review] }."
    else
      "Ticket ##{id} is unassigned."
    end
  end

  define_ticket_method :mark_for_review do |id, ticket, user|
    assigned_to = ticket[:assigned_to]
    if assigned_to == user
      ticket[:marked_for_review] = true
      "Ticket ##{id} is marked for review by `#{assigned_to}'."
    elsif !assigned_to.nil?
      "Ticket ##{id} can't be marked for review by `#{user}', as it is assigned to `#{assigned_to}'."
    else
      "Ticket ##{id} is unassigned."
    end
  end

  define_ticket_method :unmark_for_review do |id, ticket, user|
    if ticket[:marked_for_review]
      assigned_to = ticket[:assigned_to]
      if assigned_to == user
        ticket[:marked_for_review] = nil
        "Ticket ##{id} is un-marked for review by `#{assigned_to}'."
      else
        "Ticket ##{id} can't be un-marked for review by `#{user}', as it is assigned to `#{assigned_to}'."
      end
    else
      "Ticket ##{id} isn't marked for review."
    end
  end
end
