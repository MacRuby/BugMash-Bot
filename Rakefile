$:.unshift File.expand_path("../lib", __FILE__)

desc "Initialize the db"
task :init do
  require "macruby_bugmash_bot/db"
  mkdir_p(File.dirname(DB.db_path))
  DB.create!
end

desc "Update the open tickets"
task :update_open_tickets do
  require "macruby_bugmash_bot/db"
  DB.update_open_tickets!
end

desc "Run the bot"
task :run do
  require "macruby_bugmash_bot"
end
