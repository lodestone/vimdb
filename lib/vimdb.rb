module Vimdb;
  class Item; end
end
require_relative './vimdb/runner'
require_relative './vimdb/user'
require_relative './vimdb/db'
require_relative 'vimdb/item'
require_relative 'vimdb/keys'
require_relative 'vimdb/options'
require_relative 'vimdb/commands'
require_relative 'vimdb/version'

module Vimdb
  # autoload :Runner, 'vimdb/runner'
  # autoload :User,   'vimdb/user'
  # autoload :DB,     'vimdb/db'
  # autoload :Item,   'vimdb/item'

  class << self; attr_accessor :default_item, :vim, :plugins_dir; end
  self.default_item = 'keys'
  self.vim = 'vim'
  self.plugins_dir = 'bundle'

  def self.user(item_name = nil, db = DB.new)
    @user ||= User.new(item(item_name), db)
  end

  def self.item(name = nil)
    @item ||= Item.instance(name || default_item)
  end
end
