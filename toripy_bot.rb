#!/usr/local/bin/ruby
require 'rubygems'
require 'twitter'
require 'rss'
require 'sqlite3'
require 'time'

class ToripyBot
  def initialize
    create_db unless File.exist?("toripy.db")
  end
  def crawl
    puts "******************************************************************"
    puts "*                        crawl   start                           *"
    puts "******************************************************************"
    puts "start time - " + Time.now.strftime("%Y/%m/%d %H:%M")

    select_rss.each {|record|
      url = record[1]
      p record
      count = record[4]
      twit_date = record[3]
      begin
        rss = RSS::Parser.parse(url)
        rss.items.reverse.each {|item|
          ldate = item.date.strftime("%Y%m%d%H%M")
          udate = Time.parse(record[3]).strftime("%Y%m%d%H%M")
          if ldate > udate
            status = rss.channel.title + " : " + item.title + " - " + item.link
            #Twitter::Base.new("toripy" , "************").update(status)
            puts status
            count = record[4].to_i + 1
            twit_date = Time.now.to_s
          end
        }
        update_item(record[0] , twit_date , count)
      rescue => e
        puts e
      end
    }
    puts "start time - " + Time.now.strftime("%Y/%m/%d %H:%M")
    puts "******************************************************************"
    puts "*                        crawl   end                             *"
    puts "******************************************************************"
  end
  private
  def create_db
    db = get_db
    db.transaction do
      db.execute("create table RSS(id Integer primary key autoincrement, url text , active Integer)")
      db.execute("create table ITEM(id Integer primary key , twit_date date , twit_count Integer , update_date date)")
      open("list.txt").read.split(/^/).each {|url|
        url.chomp!
        next if url =~ /^¥#/
        count = db.execute("select count(*) from RSS where url='#{url}'").to_s
        next if count != "0"
        puts  "add [" + url + "]"
        db.execute("insert into RSS values(null , '#{url}' , 1)")
        ret = db.execute("select * from RSS where url='" + url + "'")[0]
        db.execute("insert into ITEM values(#{ret[0]} , '#{Time.now}',0,'#{Time.now}')")
      }
    end
  end
  def select_rss
    sql =<<-EOF
        select RSS.id , RSS.url , RSS.active , 
                ITEM.twit_date , ITEM.twit_count , ITEM.update_date
          from RSS inner join ITEM ON RSS.id = ITEM.id
          order by RSS.id
    EOF
    get_db.execute(sql)
  end
  def update_item(id , twit_date , count)
    sql =<<-EOF
      update ITEM 
        set twit_date='#{twit_date}' , twit_count=#{count} , update_date='#{Time.now.to_s}'
        where id=#{id}
    EOF
    get_db.execute(sql);
  end
  def get_db
    SQLite3::Database.new("toripy.db")
  end
end

ToripyBot.new.crawl


