#!/usr/bin/env ruby -W1
# frozen_string_literal: true

require 'optparse'

# merge
require_relative '../lib/confluence2md/table'

# merge
require_relative '../lib/confluence2md/version'

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
