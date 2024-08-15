#!/usr/bin/env ruby -W1
# frozen_string_literal: true

# Table formatting
module TableCleanup
  class << self
    def parse_cells(row)
      row.split('|').map(&:strip)[1..-1]
    end

    def header?(cells)
      cells.all? { |cell| cell =~ /^:?-+:?$/ }
    end

    def build_table(table, header)
      widths = [0] * table.first.size
      table.each do |row|
        row.each_with_index do |cell, col|
          widths[col] = cell.size if widths[col] < cell.size
        end
      end

      string = String.new

      first_row = header ? table.shift : [''] * table.first.size
      render_preamble string
      render_row nil, first_row, string, widths
      render_preamble string
      render_header header, string, widths

      table.each do |row|
        render_preamble string
        render_row header, row, string, widths
      end

      string
    end

    def render_preamble(string)
      string << '|'
    end

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

    def render_row(header, row, string, widths)
      idx = 0
      row.zip(widths).each do |cell, width|
        width = 78 if width >= 80
        content = header ? align(header[idx], cell, width) : cell.ljust(width, ' ')
        string << " #{content} |"
        idx += 1
      end
      string << "\n"
    end

    def render_header(header, string, widths)
      header ||= [:left] * widths.size
      header.zip(widths).each do |align, width|
        string << ':' if align == :left
        width = 78 if width > 80
        string << '-' * (width + (align == :center ? 2 : 1))
        string << ':' if align == :right
        string << '|'
      end
      string << "\n"
    end

    def clean(content)
      table = nil
      header = nil
      output = String.new
      rx = /^\s*(\|(.+?\|)+)\s*$/

      lines = content.split(/\n/)

      lines.each_with_index do |line, idx|
        if line =~ rx
          row = Regexp.last_match(1)

          table ||= []

          cells = parse_cells(row)

          if header?(cells)
            header ||= cells.map do |cell|
              if cell[0, 1] == ':' && cell[-1, 1] == ':'
                :center
              elsif cell[-1, 1] == ':'
                :right
              else
                :left
              end
            end
          else
            table << cells
          end

          if idx == lines.count - 1
            output << if table
                        "#{build_table(table, header)}\n"
                      else
                        "#{line}\n"
                      end
          end
        elsif table
          output << "#{build_table(table, header)}#{line}\n"
          table = header = nil
        else
          output << "#{line}\n"
        end
      end
      output
    end
  end
end

if ARGV.count.positive?
  ARGV.each do |arg|
    target = File.expand_path(arg)
    if File.exist?(target)
      warn "Processing #{target}"
      content = IO.read(target)
      File.open("#{target.sub(/\.(markdown|md)$/, '')}-cleaned.md", 'w') { |f| f.puts TableCleanup.clean(content) }
    else
      puts "File #{target} doesn't exist"
    end
  end
else
  puts "Usage: #{File.basename(__FILE__)} MARKDOWN_FILE_PATH"
  exit 1
end
