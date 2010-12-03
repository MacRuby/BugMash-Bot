# encoding: UTF-8

require "macruby_bugmash_bot/ticket"

class Trac
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

  def ticket(id)
    DB.tickets.filter(:id => id).first
  end

  def ticket_message(id)
    t = ticket(id)
    "#{t[:summary]} (#{t[:link]})"
  end

  def _ticket_message(t)
    "#{t[:summary]} (#{t[:link]})"
  end

  def user(name)
    if (tickets = DB.user_tickets(name)) && !tickets.empty?
      result = tickets.map { |t| _ticket_message(t) }
      result.unshift("You are currently working on #{pluralize(result.size, 'ticket')}:")
      result
    else
      ["You don't have any tickets assigned."]
    end
  end

  def marked_for_review
    result = DB.tickets.filter(:marked_for_review => true).order(:id).all
    if result.empty?
      ["There are currently no open tickets marked for review."]
    else
      result = result.map { |t| _ticket_message(t) }
      result.unshift("There #{result.size == 1 ? 'is' : 'are'} currently #{pluralize(result.size, 'ticket')} marked for review:")
      result
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
    if assigned_to = DB.ticket_user(id)
      if assigned_to[:name] == user
        "Ticket ##{id} is already assigned to `#{user}'."
      else
        "Ticket ##{id} can't be assigned to `#{user}', as it is already assigned to `#{assigned_to[:name]}'."
      end
    else
      user_id = DB.find_or_insert_user(user)
      DB.tickets.filter(:id => id).update(:assigned_to => user_id)
      "Ticket ##{id} is now assigned to `#{user}'."
    end
  end

  define_ticket_method :resign_from_ticket do |id, ticket, user|
    if assigned_to = DB.ticket_user(id)
      if assigned_to[:name] == user
        DB.tickets.filter(:id => id).update(:assigned_to => nil)
        "Ticket ##{id} was resigned by `#{user}'."
      else
        "Ticket #19 can't be unassigned by `#{user}', as it is assigned to `#{assigned_to[:name]}'."
      end
    else
      "Ticket ##{id} is already unassigned."
    end
  end

  define_ticket_method :ticket_status do |id, ticket, _|
    if user = DB.ticket_user(id)
      "Ticket ##{id} is assigned to `#{user[:name]}'#{ ' and marked for review' if ticket[:marked_for_review] }."
    else
      "Ticket ##{id} is unassigned."
    end
  end

  define_ticket_method :mark_for_review do |id, ticket, user|
    if assigned_to = DB.ticket_user(id)
      if assigned_to[:name] == user
        DB.tickets.filter(:id => id).update(:marked_for_review => true)
        "Ticket ##{id} is marked for review by `#{assigned_to[:name]}'."
      else
        "Ticket ##{id} can't be marked for review by `#{user}', as it is assigned to `#{assigned_to[:name]}'."
      end
    else
      "Ticket ##{id} is unassigned."
    end
  end

  define_ticket_method :unmark_for_review do |id, ticket, user|
    if ticket[:marked_for_review]
      assigned_to = DB.ticket_user(id)
      if assigned_to[:name] == user
        DB.tickets.filter(:id => id).update(:marked_for_review => false)
        "Ticket ##{id} is unmarked for review by `#{assigned_to[:name]}'."
      else
        "Ticket ##{id} can't be unmarked for review by `#{user}', as it is assigned to `#{assigned_to[:name]}'."
      end
    else
      "Ticket ##{id} isn't marked for review."
    end
  end

  private

  def pluralize(count, string)
    if count == 1
      "#{count} #{string}"
    else
      "#{count} #{string}s"
    end
  end
end
