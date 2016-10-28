require_relative 'item'
class Vimdb::Keys < Vimdb::Item
  class << self; attr_accessor :config end
  self.config = {
    modifiers: {'<Esc>' => 'E'},
    mode_map: {'!' => 'ci', 'v' => 'vs', 'x' => 'v', 'l' => 'ci'},
  }

  def initialize
    @modifiers, @mode_map = self.class.config.values_at(:modifiers, :mode_map)
    @plugins_dir = Vimdb.plugins_dir
  end

  def create
    keys = parse_index_file create_index_file
    @leader ||= get_leader
    @modifiers[@leader] ||= 'L'
    keys + parse_map_file(create_map_file)
  end

  def search(keys, query, options = {})
    keys = super
    if options[:mode]
      keys.select! do |key|
        options[:mode].split('').any? {|m| key[:mode].include?(m) }
      end
    end
    keys
  end

  def info
    "Created using index.txt and :map"
  end

  def fields
    [:key, :mode, :from, :desc]
  end

  private

  def get_leader
    file = tempfile(:keys_leader) do |file|
      leader_cmd = %[silent! echo exists("mapleader") ? mapleader : ""]
      vim "redir! > #{file}", leader_cmd, 'redir END'
    end
    leader = File.readlines(file).last.chomp
    {' ' => '<Space>', '' => '\\'}[leader] || leader
  end

  def create_index_file
    tempfile(:keys_index) do |file|
      vim 'silent help index.txt', "silent! w! #{file}"
    end
  end

  def parse_index_file(file)
    lines = File.read(file).split("\n")
    sections = lines.slice_before(/^={10,}/).to_a
    header_modes = [
      ['1. Insert mode', 'i'], ['2.1', 'ovs'], ['2.', 'n'],
      ['3. Visual mode', 'vs'], ['4. Command-line editing', 'c']
    ]

    keys = []
    # skip intro and last Ex section
    sections[1..-2].each do |section_lines|
      mode = header_modes.find {|k,v|
        section_lines[1] =~ Regexp.new('^' + Regexp.quote(k))
      }.to_a[1] || '?'

      #drop section header
      section_lines = section_lines.drop_while {|e| e !~ /^\|/ }

      section_lines.each do |line|
        cols = line.split(/\t+/)
        if cols.size >= 3
          desc = cols[-1] == '"' ? keys[-1][:desc] : cols[-1]
          keys << create_index_key(mode, cols[-2], desc)
          keys.pop if keys[-1][:desc] == 'not used'
        elsif cols.size == 2
          # add desc from following lines
          if cols[0] == ''
            if cols[1] !~ /^(Meta characters|not used)/
              keys[-1][:desc] << ' ' if !keys[-1][:desc].empty?
              keys[-1][:desc] << cols[1].gsub(/^\s*\d?|\s*$/, '')
            end
          else
            key, desc = cols[1].include?('use register') ?
              cols[1].split(/\s+/, 2) : [cols[1], nil]
            keys << create_index_key(mode, key, desc)
          end
        elsif cols.size == 1
          tag, key = line.split(/\s+/, 2)
          if tag == '|i_CTRL-V_digit|'
            key, desc = key.split(/(?<=})/)
            keys << create_index_key(mode, key, desc)
          elsif tag == '|CTRL-W_g_CTRL-]|'
            key, desc = key.split(/(?<=\])/)
            keys << create_index_key(mode, key, desc)
          else
            keys << create_index_key(mode, key)
          end
        end
      end
    end
    keys
  end

  def create_index_key(mode, key, desc = nil)
    desc = desc ? desc.gsub(/^\s*\d?\s*|\s*$/, '') : ''
    { mode: mode, key: translate_index_key(key), desc: desc, from: 'default' }
  end

  def translate_index_key(key)
    key.gsub(/CTRL-(\S)/) {|s| "C-#{$1.downcase}" }
  end

  def create_map_file
    tempfile(:keys_map) do |file|
      vim "redir! > #{file}", "verbose map", "verbose map!", 'redir END'
    end
  end

  def parse_map_file(file)
    lines = File.read(file).strip.split("\n")
    lines.slice_before {|e| e !~ /Last set/ }.map do |arr|
      key = {}
      key[:file] = arr[1].to_s[%r{Last set from (\S+)}, 1] or next
      match = key[:file].to_s.match(%r{/#{@plugins_dir}/(?<plugin>[^/]+)})

      key[:from] = match ? match[:plugin] + ' plugin' : 'user'

      key[:key]  = arr[0][/^\S*\s+(\S+)/, 1]
      next if key[:key][/^(<Plug>|<SNR>)/]
      key[:key] = translate_map_key(key[:key])

      key[:desc] = arr[0][/^\S*\s+\S+\s+\*?\s*(.*)$/, 1]
      key[:mode] = (mode = arr[0][/^[nvsxo!ilc]+/]) ?
        @mode_map[mode] || mode : 'nvso'
      key
    end.compact
  end

  def translate_map_key(key)
    if match = /^(?<modifier>#{Regexp.union(*@modifiers.keys)})(?<first>\S)(?<rest>.*$)/.match(key)
      rest = match[:rest].empty? ? '' : ' ' + match[:rest]
      "#{@modifiers[match[:modifier]]}-#{match[:first]}" + rest
    elsif match = /^<(?<ctrl>C-[^>])>(?<rest>.*$)/.match(key)
      rest = match[:rest].empty? ? '' :
        ' ' + match[:rest].gsub(/<(C-[^>])>/, '\1')
      (match[:ctrl] + rest).gsub(/C-([A-Z])/) {|s| "C-#{$1.downcase}" }
    else
      key
    end
  end
end
