#!/usr/local/bin/ruby
require 'rubygems'
require 'twitter'
require 'rss'
require 'atomutil'
require 'sqlite3'
require 'time'
require 'yaml'

class ToripyBot
  def initialize
    yaml = YAML.load_file("toripy.yaml")
    @id = yaml["id"]
    @password = yaml["password"]
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
            get_twitter.update(status)
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
  def follow
    t = get_twitter
    friends = []
    for i in 1...99
      f = t.friends(:page => i)
      break if f.length == 0
      f.each{|u| friends.push u.screen_name}
    end
    followers = []
    for i in 1...99
      f = t.followers(:page => i)
      break if f.length == 0
      f.each{|u| followers.push u.screen_name}
    end
    puts friends.length
    puts followers.length
    followers.each{|u|
      next if friends.include? u
      print "follow #{u}"
      begin
        t.friendship_create(u)
        puts " -> OK"
      rescue
        print " -> error"
        begin
          t.friendship_destroy(u)
          print " -> remove"
        rescue
        end
        puts ""
      end
    }
  end
  def add_rss(url)
    url.chomp! unless url.frozen?
    return if url =~ /^¥#/
    db = get_db
    count = db.execute("select count(*) from RSS where url='#{url}'").to_s
    if count != "0"
      puts "already exist"
      return
    end
    puts  "add [" + url + "]"
    db.execute("insert into RSS values(null , '#{url}' , 1)")
    ret = db.execute("select * from RSS where url='" + url + "'")[0]
    db.execute("insert into ITEM values(#{ret[0]} , '#{Time.now}',0,'#{Time.now}')")
  end
  def setup
    create_db unless File.exist?("toripy.db")
  end
  def search_follow
    auth = Atompub::Auth::Wsse.new :username => @id , :password => @password 
    atom = Atompub::Client.new(:auth => auth)
    followed = []
    list = [
      "http://search.twitter.com/search.atom?q=%E9%B3%A5%E5%8F%96", #鳥取
      "http://search.twitter.com/search?q=%E9%B3%A5%E5%8F%96%E7%A0%82%E4%B8%98", #鳥取砂丘
      "http://search.twitter.com/search?q=%E9%B3%A5%E5%A4%A7", #鳥大
      "http://search.twitter.com/search?q=%E5%B3%B6%E6%A0%B9", #島根
      "http://search.twitter.com/search?q=%E5%A4%A7%E5%B1%B1", #大山
      "http://search.twitter.com/search?q=%E7%B1%B3%E5%AD%90", #米子
      "http://search.twitter.com/search?q=%E5%9B%A0%E5%B9%A1", #因幡
    ].each{|url|
      atom.get_feed(url).entries.each{|e|
        if e.author.uri =~ /http(.*?)twitter.com(.*)/
          name = $2.slice(1,$2.length)
          next if followed.include? name
          print "follow #{name} ... "
            get_twitter.friendship_create(name)
            puts "OK"
            puts e
            puts "NG"
          followed.push name
        end
      }
    }
  end
  private
  def create_db
    db = get_db
    db.execute("create table RSS(id Integer primary key autoincrement, url text , active Integer)")
    db.execute("create table ITEM(id Integer primary key , twit_date date , twit_count Integer , update_date date)")
    open("list.txt").read.split(/^/).each {|url| add_rss(url)}
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
  def get_twitter
    httpauth = Twitter::HTTPAuth.new(@id, @password)
    Twitter::Base.new(httpauth)
  end
end

if ARGV.length == 0
  ToripyBot.new.crawl
  ToripyBot.new.follow
elsif ARGV.length == 2 && ARGV[0] == "add_rss"
  ToripyBot.new.add_rss ARGV[1]
elsif ARGV.length == 1 && ARGV[0] == "follow"
  ToripyBot.new.follow
elsif ARGV.length == 1 && ARGV[0] == "setup"
  ToripyBot.new.setup
elsif ARGV.length == 1 && ARGV[0] == "search_follow"
  ToripyBot.new.search_follow
end


