require 'rubygems'
require 'activesupport'

require 'activetokyo/faketokyocabinet'
require 'activetokyo/base'
require 'activetokyo/class_methods'
require 'activetokyo/associations'

ActiveTokyo::Base.class_eval do
  include ActiveTokyo::ClassMethods
  include ActiveTokyo::Associations
end
