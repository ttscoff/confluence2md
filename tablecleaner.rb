#!/usr/bin/env ruby -W1
# frozen_string_literal: true

require 'optparse'

##
## C2MD module
##
## @api public
##
module C2MD
  ##
  ## Version
  ##
  VERSION = '1.0.26'
end

# Table formatting, cleans up tables in content
# @api public
class TableCleanup
  # Max cell width for formatting, defaults to 30
  attr_writer :max_cell_width
  # Max table width for formatting, defaults to 60
  attr_writer :max_table_width
  # The content to process
  attr_writer :content

  ##
  ## Initialize a table cleaner
  ##
  ## @param      content  [String] The content to clean
  ## @param      options  [Hash] The options
  ##
  def initialize(content = nil, options = nil)
    @content = content ? content : ''
    @max_cell_width = options && options[:max_cell_width] ? options[:max_cell_width] : 30
    @max_table_width = options && options[:max_table_width] ? options[:max_table_width] : nil
  end

  ##
  ## Split a row string on pipes
  ##
  ## @param      row   [String] The row string
  ##
  ## @return [Array] array of cell strings
  ##
  def parse_cells(row)
    row.split('|').map(&:strip)[1..-1]
  end

  ##
  ## Builds a formatted table
  ##
  ## @param      table [Array<Array>]   The table, an array of row arrays
  ##
  ## @return [String] the formatted table
  ##
  def build_table(table)
    @widths = [0] * table.first.size

    table.each do |row|
      row.each_with_index do |cell, col|
        if @widths[col]
          @widths[col] = cell.size if @widths[col] < cell.size
        else
          @widths[col] = cell.size
        end
      end
    end

    @string = String.new

    first_row = table.shift
    render_row first_row
    render_alignment

    table.each do |row|
      render_row row
    end

    @string
  end

  ##
  ## Align content withing cell based on header alignments
  ##
  ## @param      string     [String] The string to align
  ## @param      width      [Integer] The cell width
  ##
  ## @return [String] aligned string
  ##
  def align(alignment, string, width)
    case alignment
    when :left
      string.ljust(width, ' ')
    when :right
      string.rjust(width, ' ')
    when :center
      string.center(width, ' ')
    end
  end

  ##
  ## Render a row
  ##
  ## @param      row     [Array] The row of cell contents
  ##
  ## @return [String] the formatted row
  ##
  def render_row(row)
    idx = 0
    @max_cell_width = @max_table_width / row.count if @max_table_width

    @string << '|'
    row.zip(@widths).each do |cell, width|
      width = @max_cell_width - 2 if width >= @max_cell_width
      if width.zero?
        @string << '|'
      else
        content = @alignment ? align(@alignment[idx], cell, width) : cell.ljust(width, ' ')
        @string << " #{content} |"
      end
      idx += 1
    end
    @string << "\n"
  end

  ##
  ## Render the alignment row
  ##
  def render_alignment
    @string << '|'
    @alignment.zip(@widths).each do |align, width|
      @string << ':' if align == :left
      width = @max_cell_width - 2 if width >= @max_cell_width
      @string << '-' * (width + (align == :center ? 2 : 1))
      @string << ':' if align == :right
      @string << '|'
    end
    @string << "\n"
  end

  ##
  ## String helpers
  ##
  class ::String
    ##
    ## Ensure leading and trailing pipes
    ##
    ## @return     [String] string with pipes
    ##
    def ensure_pipes
      strip.gsub(/^\|?(.*?)\|?$/, '|\1|')
    end

    def alignment?
      self =~ /^[\s|:-]+$/ ? true : false
    end
  end

  ##
  ## Clean tables within content
  ##
  def clean
    table_rx = /^(?ix)(?<table>
    (?<header>\|?(?:.*?\|)+.*?)\s*\n
    ((?<align>\|?(?:[:-]+\|)+[:-]*)\s*\n)?
    (?<rows>(?:\|?(?:.*?\|)+.*?(?:\n|\Z))+))/

    @content.gsub!(/(\|?(?:.+?\|)+)\n\|\n/) do
      m = Regexp.last_match
      cells = parse_cells(m[1]).count
      "#{m[1]}\n#{'|' * cells}\n"
    end

    tables = @content.to_enum(:scan, table_rx).map { Regexp.last_match }

    tables.each do |t|
      table = []

      if t['align'].nil?
        cells = parse_cells(t['header'])
        align = "|#{([':---'] * cells.count).join('|')}|"
      else
        align = t['align']
      end

      @alignment = parse_cells(align.ensure_pipes).map do |cell|
        if cell[0, 1] == ':' && cell[-1, 1] == ':'
          :center
        elsif cell[-1, 1] == ':'
          :right
        else
          :left
        end
      end

      lines = t['table'].split(/\n/)
      lines.delete_if(&:alignment?)

      lines.each do |row|
        # Ensure leading and trailing pipes
        row = row.ensure_pipes

        cells = parse_cells(row)

        table << cells
      end

      @content.sub!(/#{Regexp.escape(t['table'])}/, "#{build_table(table)}\n")
    end

    @content
  end
end

options = {
  # debug: false,
  max_table_width: nil,
  max_cell_width: 30,
  output: nil,
  stdout: false
}

opt_parser = OptionParser.new do |opt|
  opt.banner = <<~EOBANNER
    Run with file arguments (Markdown containing tables). Cleaned output will be saved to
    [FILENAME]-cleaned.md unless -o option is provided.

    Usage: #{File.basename(__FILE__)} [OPTIONS] [FILE [FILE]]
  EOBANNER
  opt.separator  ''
  opt.separator  'Options:'

  opt.on('-o', '--output FILENAME', 'Save output to specified file') do |option|
    options[:output] = option
  end

  opt.on('-t', '--max-table-width WIDTH', 'Define a maximum table width') do |option|
    options[:max_table_width] = option.to_i
  end

  opt.on('-c', '--max-cell-width WIDTH', 'Define a maximum cell width. Overriden by --max_table_width') do |option|
    options[:max_cell_width] = option.to_i
  end

  opt.on('--stdout', 'When operating on single file, output to STDOUT instead of filename') do
    options[:stdout] = true
  end

  # opt.on_tail('-d', '--debug', 'Display debugging info') do
  #   options[:debug] = true
  # end

  opt.on_tail('-h', '--help', 'Display help') do
    puts opt
    Process.exit 0
  end

  opt.on_tail('-v', '--version', 'Display version number') do
    puts "#{File.basename(__FILE__)} v#{C2MD::VERSION}"
    Process.exit 0
  end
end

opt_parser.parse!

if ARGV.count.positive?
  ARGV.each do |arg|
    target = File.expand_path(arg)
    if File.exist?(target)
      warn "Processing #{target}"
      content = IO.read(target)
      tc = TableCleanup.new(content, { max_cell_width: 30 })
      output = tc.clean
      if options[:stdout]
        puts output
      else
        file = options[:output] ? File.expand_path(options[:output]) : "#{target.sub(/\.(markdown|md)$/, '')}-cleaned.md"
        File.open(file, 'w') { |f| f.puts output }
        warn "Cleaned output written to #{file}"
      end
    else
      puts "File #{target} doesn't exist"
    end
  end
else
  # tc = TableCleanup.new
  # tc.content = DATA.read
  # tc.max_table_width = 60
  # puts tc.clean
  puts "File argument(s) required"
  Process.exit 1
end

__END__
Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod
tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,
quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo
consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse
cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

|header 1| header 2|
|:----|---:|
| data1|data2|

another| table
|:-----|:----:|
one|Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
two|a much shorter cell|
|three|`another row`|
