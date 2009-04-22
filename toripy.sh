#!/bin/csh

#setenv path = ($path $HOME/bin $HOME/lib/ruby/gem/bin)
setenv RUBYLIB $HOME/lib/ruby/site_ruby/1.8:$HOME/lib
setenv GEM_HOME $HOME/lib/ruby/gem

ruby /home/basyura/cron/toripy/toripy_bot.rb
