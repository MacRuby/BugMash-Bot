$:.unshift File.expand_path("../../vendor/cinch/lib", __FILE__)
require "cinch"
require "macruby_bugmash_bot/trac"

bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "irc.freenode.org"
    c.nick     = "BugMash-bot"
    c.channels = ["#cinch-bots"]

    @trac = Trac.new
  end

  on :channel, "hello" do |m|
    m.reply "Hello, #{m.user.nick}"
  end

  on :channel, "!gimme" do |m|
    m.reply @trac.open_ticket
  end

  on :channel, /^!work (\d+)/ do |m, id|
    m.reply @trac.assign_ticket(id, m.user.nick)
  end

  on :channel, /^!stop (\d+)/ do |m, id|
    m.reply @trac.resign_from_ticket(id, m.user.nick)
  end

  on :channel, /^!status (\d+)/ do |m, id|
    m.reply @trac.ticket_status(id, m.user.nick)
  end

  on :channel, /^!review (\d+)/ do |m, id|
    m.reply @trac.mark_for_review(id, m.user.nick)
  end

  on :channel, /^!unreview (\d+)/ do |m, id|
    m.reply @trac.unmark_for_review(id, m.user.nick)
  end

  on :message, "!me" do |m|
    @trac.user(m.user.nick).each do |msg|
      m.user.send(msg)
    end
  end

  on :message, "!marked_for_review" do |m|
    @trac.marked_for_review.each do |msg|
      m.user.send(msg)
    end
  end
end

bot.start
