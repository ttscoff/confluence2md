# frozen_string_literal: true

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
      next unless row

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

    return unless row

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
    return unless @alignment

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

      next unless parse_cells(align.ensure_pipes)

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
