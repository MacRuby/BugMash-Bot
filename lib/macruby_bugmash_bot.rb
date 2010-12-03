$:.unshift File.expand_path("../../vendor/cinch/lib", __FILE__)
require "cinch"

bot = Cinch::Bot.new do
  configure do |c|
    c.server = "irc.freenode.org"
    c.channels = ["#cinch-bots"]
  end

  on :channel, "hello" do |m|
    m.reply "Hello, #{m.user.nick}"
  end
end

bot.start
