# encoding: UTF-8

$:.unshift File.expand_path("../../vendor/cinch/lib", __FILE__)
require "cinch"
require "macruby_bugmash_bot/trac"

bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "irc.freenode.org"
    c.nick     = "BugMash-bot"
    c.channels = ["#macruby"]

    @trac = Trac.new
  end

  HELP = [
    "‘#<id>’ Get info about a ticket.",
    "‘!gimme’ This command will tell you of a single ticket that is available.",
    "‘!work <id>’ This command tells the bot that you are now working on a ticket.",
    "‘!stop <id>’ This command tells the bot that you are no longer working on a ticket.",
    "‘!status <id>’ This command asks the bot the status of a particular ticket. It will respond by saying who's working on it.",
    "‘!review <id>’ Marks the ticket for review. MacRuby core will monitor this to see what's ready to be reviewed.",
    "‘!unreview <id>’ Unmarks the ticket to be reviewed.",
    "‘!me’ Private messages you telling you the number of tickets you're working on and lists them off.",
    "‘!marked’ Private messages you telling you what the tickets are that are ready to be reviewed."
  ]

  on :channel, "!help" do |m|
    HELP.each { |msg| m.user.send(msg) }
  end

  # TODO move this out
  on :channel, "!total" do |m|
    m.reply "There are a total of #{DB.tickets.filter(:closed => false).count} open tickets."
  end

  on :channel, "!gimme" do |m|
    m.reply @trac.open_ticket
  end

  on :channel, /^#(\d+)/ do |m, id|
    m.reply @trac.ticket_info(id, m.user.nick)
  end

  on :channel, /^!work #?(\d+)/ do |m, id|
    m.reply @trac.assign_ticket(id, m.user.nick)
  end

  on :channel, /^!stop #?(\d+)/ do |m, id|
    m.reply @trac.resign_from_ticket(id, m.user.nick)
  end

  on :channel, /^!status #?(\d+)/ do |m, id|
    m.reply @trac.ticket_status(id, m.user.nick)
  end

  on :channel, /^!review #?(\d+)/ do |m, id|
    m.reply @trac.mark_for_review(id, m.user.nick)
  end

  on :channel, /^!unreview #?(\d+)/ do |m, id|
    m.reply @trac.unmark_for_review(id, m.user.nick)
  end

  on :message, "!me" do |m|
    @trac.user(m.user.nick).each do |msg|
      m.user.send(msg)
    end
  end

  on :message, "!marked" do |m|
    @trac.marked_for_review.each do |msg|
      m.user.send(msg)
    end
  end
end

bot.start
