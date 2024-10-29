#!/usr/bin/env ruby -W1
# frozen_string_literal: true

# Requirements:
#   Ruby 3.x
#   Pandoc installed in $PATH

require "fileutils"
require "shellwords"
require "optparse"
require "erb"
require "open3"
begin
  require "rbconfig"
rescue LoadError
end

# merge
require_relative "../lib/confluence2md/version"

# merge
require_relative "../lib/confluence2md/tty"

# merge
require_relative "../lib/confluence2md/cli"

# merge
require_relative "../lib/confluence2md/table"

# merge
require_relative "../lib/confluence2md/html2markdown"

# merge
require_relative "../lib/confluence2md/confluence2markdown"

options = {
  clean_dirs: false,
  clean_tables: true,
  color: true,
  debug: false,
  escape: false,
  fix_headers: true,
  fix_hierarchy: true,
  fix_tables: false,
  flatten_attachments: true,
  max_table_width: nil,
  max_cell_width: 30,
  rename_files: true,
  include_source: false,
  strip_emoji: true,
  strip_meta: false,
  update_links: true,
}

opt_parser = OptionParser.new do |opt|
  opt.banner = <<~EOBANNER
    Run in a folder full of HTML files, or pass a single HTML file as argument.
    If passing a single HTML file, optionally specify an output file as second argument.

    Usage: #{File.basename(__FILE__)} [OPTIONS] [FILE [OUTPUT_FILE]]
  EOBANNER
  opt.separator ""
  opt.separator "Options:"

  opt.on("-c", "--clean", "Clear output directories before converting") do
    options[:clean_dirs] = true
  end

  opt.on("-e", "--[no-]strip-emoji", "Strip emoji (default true)") do |option|
    options[:strip_emoji] = option
  end

  opt.on("--[no-]escape", "Escape special characters (default false)") do |option|
    options[:escape] = option
  end

  opt.on("-f", "--[no-]fix-headers", "Bump all headers except first h1 (default true)") do |option|
    options[:fix_headers] = option
  end

  opt.on("-o", "--[no-]fix-hierarchy", "Fix header nesting order (default true)") do |option|
    options[:fix_hierarchy] = option
  end

  opt.on("-s", "--strip-meta", "Strip Confluence metadata (default false)") do
    options[:strip_meta] = true
  end

  opt.on("-t", "--[no-]convert-tables", "Convert tables to Markdown (default false)") do |option|
    options[:fix_tables] = option
  end

  opt.on("--[no-]clean-tables", "Format converted tables, only valid with --convert-tables (default true)") do |option|
    options[:clean_tables] = option
  end

  opt.on("--max-table-width WIDTH", "If using --clean-tables, define a maximum table width") do |option|
    options[:max_table_width] = option.to_i
  end

  opt.on(["--max-cell-width WIDTH", "If using --clean-tables, define a maximum cell width.",
          "Overriden by --max_table_width"].join(" ")) do |option|
    options[:max_cell_width] = option.to_i
  end

  opt.on("--[no-]flatten-images", "Flatten attachments folder and update links (default true)") do |option|
    options[:flatten_attachments] = option
  end

  opt.on("--[no-]rename", "Rename output files based on page title (default true)") do |option|
    options[:rename_files] = option
  end

  opt.on("--[no-]source", "Include an HTML comment with name of original HTML file (default false)") do |option|
    options[:include_source] = option
  end

  opt.on("--stdout", "When operating on single file, output to STDOUT instead of filename") do
    options[:rename_files] = false
  end

  opt.on("--[no-]update-links", "Update links to local files (default true)") do |option|
    options[:update_links] = option
  end

  opt.separator ""
  opt.separator "CLI"

  opt.on_tail("--[no-]colorize", "Colorize command line messages with ANSI escape codes") do |option|
    options[:color] = option
    CLI.coloring = options[:color]
  end

  # Compatibility with other CLI tools
  opt.on("--color WHEN", 'Colorize terminal output, "always, never, auto?"') do |option|
    options[:color] = option =~ /^[nf]/ ? false : true
    CLI.coloring = options[:color]
  end

  opt.on_tail("-d", "--debug", "Display debugging info") do
    options[:debug] = true
  end

  opt.on_tail("-h", "--help", "Display help") do
    puts opt
    Process.exit 0
  end

  opt.on_tail("-v", "--version", "Display version number") do
    puts "#{File.basename(__FILE__)} v#{C2MD::VERSION}"
    Process.exit 0
  end
end

opt_parser.parse!

options[:clean_tables] = options[:fix_tables] ? options[:clean_tables] : false

c2m = Confluence2MD.new(options)

# If a single file is passed as an argument, process just that file
if ARGV.count.positive?
  html = File.expand_path(ARGV[0])
  res = c2m.single_file(html)
  if res && ARGV[1]
    markdown = File.expand_path(ARGV[1])
    File.open(markdown, "w") { |f| f.puts res }
    CLI.finished "#{html} => #{markdown}"
  elsif res
    puts res
  end
  # If text is piped in, process STDIN
elsif $stdin.stat.size.positive?
  input = $stdin.read.force_encoding("utf-8")
  puts c2m.handle_stdin(input)
  # Otherwise, assume we're in a folder full of HTML files
  # subfolders for output will be created
  # url-based media is downloaded and saved, relative paths are updated
else
  c2m.all_html
end
