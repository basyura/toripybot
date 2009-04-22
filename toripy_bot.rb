#!/usr/local/bin/ruby
require 'rubygems'
require 'twitter'
require 'rss'
require 'pstore'

class ToripyBot
  TOUCH_FILE_PATH = "/home/basyura/cron/toripy/toripy_touch.pstore"
  LIST_FILE_PATH  = "/home/basyura/cron/toripy/list.txt"
  def crawl
    puts "******************************************************************"
    puts "*                        crawl   start                           *"
    puts "******************************************************************"
    puts "start time - " + Time.now.strftime("%Y/%m/%d %H:%M")

    PStore.new(TOUCH_FILE_PATH).transaction {|pstore|
      file = open(LIST_FILE_PATH)
      file.read.split.each {|url| url.chomp!
        next if url == ""
        next if url =~ /^#/
        puts url
        touch = pstore[url] ||= Time.now.strftime("%Y%m%d%H%M")
        latest = touch
        puts "touch is " + touch
        begin
          rss = RSS::Parser.parse(url)
          rss.items.reverse.each {|item|
            date = item.date.strftime("%Y%m%d%H%M")
            if date > touch
              status = rss.channel.title + " : " + item.title + " - " + item.link
              Twitter::Base.new("toripy" , "xxxxxxxxxxxx").update(status)
              puts status
              latest = date if date > latest
            end
          }
        rescue => e
          puts e
        end
        pstore[url] = latest
      }
      file.close
    }
    puts "start time - " + Time.now.strftime("%Y/%m/%d %H:%M")
    puts "******************************************************************"
    puts "*                        crawl   end                             *"
    puts "******************************************************************"
  end
end

ToripyBot.new.crawl


