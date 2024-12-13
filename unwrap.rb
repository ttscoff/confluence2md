#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'

options = {
  overwrite: false,
  stdout: false
}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] [file1 file2 ...]\nPass input via stdin or as file argument(s)."
  opts.separator 'Options:'
  opts.on('-o', '--overwrite',
          'Write unwrapped output to files in place (otherwise creates a separate *.unwrapped[.ext] file)') do
    options[:overwrite] = true
  end

  opts.on('-s', '--stdout', 'Write unwrapped output to stdout, even when passing file arguments') do
    options[:stdout] = true
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparse.parse!

# String extension to unwrap paragraphs
class ::String
  def unwrap_ps
    input = dup

    # Unwrap paragraphs respecting list items
    rx = /(.*?\S\r?\n[\t ]*(?!\s*(\r?\n|\* |\+ |- |\d+\. )))+/
    puts input =~ rx ? true : false
    input.gsub!(rx) do |m|
      m.gsub(/\n/, ' ')
       .gsub(/\s{2,}/) do
         t = Regexp.last_match
         t.post_match[0] =~ /([-*+] |\d+\. )/ ? t : ' '
       end
    end
    input
  end
end

if ARGV.count.positive?
  ARGV.each do |file|
    input = IO.read(file)
    output = input.unwrap_ps

    if options[:stdout]
      puts output
    else
      outfile = file
      outfile = file.sub(/(\.\w+)?$/, '.unwrapped\1') unless options[:overwrite]
      File.open(outfile, 'w') { |f| f.write(output) }
      warn "Unwrapped content written to #{outfile}"
    end
  end
else
  puts $stdin.read.unwrap_ps
end
