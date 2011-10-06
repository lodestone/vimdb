require 'tempfile'

class Keys::VimKeys
  class << self;  attr_accessor :plugins_dir; end
  self.plugins_dir = 'plugins'

  def self.create
    index_file = generate_index_file
    keys = parse_index_file index_file
    map_file = generate_map_file
    keys + parse_map_file(map_file)
  end

  def self.generate_index_file
    file = Tempfile.new('vim-index').path
    system %[ vim -c 'colorscheme default | help index.txt | ] +
      %[silent w! #{file} | qa']
    file
  end

  def self.parse_index_file(file)
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

      section_lines.each do |e|
        cols = e.split(/\t+/)
        if cols.size >= 3
          key = cols[-2].gsub('CTRL-', 'C-')
          keys << {mode: mode, key: key, desc: cols[-1].strip }
        # add desc from following lines
        elsif cols.size == 2 && cols[0] == ''
          keys[-1][:desc] += ' ' + cols[1].strip
        end
      end
    end
    keys
  end

  def self.generate_map_file
    file = Tempfile.new('vim-map').path
    system %[ vim -c 'colorscheme default | redir! > #{file} | ] +
      "silent! verbose map | redir END | quit'"
    file
  end

  def self.parse_map_file(file)
    mode_map = {'!' => 'ci', 'v' => 'vs', 'x' => 'v', 'l' => 'ci'}
    lines = File.read(file).strip.split("\n")
    lines.slice_before {|e| e !~ /Last set/ }.map do |arr|
      key = {}

      key[:file] = arr[1].to_s[%r{Last set from (\S+)}, 1]
      key[:plugin] = key[:file].to_s[%r{#{plugins_dir}/([^/]+)\S+}, 1]
      next if file.nil?

      key[:key]  = arr[0][/^\S*\s+(\S+)/, 1]
      next if key[:key][/^<Plug>/]

      key[:desc] = arr[0][/^\S*\s+\S+\s+(.*)$/, 1]
      key[:mode] = (mode = arr[0][/^[nvsxo!ilc]+/]) ?
        mode_map[mode] || mode : 'nvso'
      key
    end.compact
  end
end