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

##
## C2MD module
##
## @api public
##
module C2MD
  ##
  ## Version
  ##
  VERSION = "1.0.34"
end

module TTY
  # Responsible for detecting terminal screen size
  #
  # @api public
  module Screen
    # The Ruby configuration
    #
    # @return [Hash]
    #
    # @api private
    RUBY_CONFIG = defined?(::RbConfig) ? ::RbConfig::CONFIG : {}
    private_constant :RUBY_CONFIG

    # Define module method as private
    #
    # @return [void]
    #
    # @api private
    def self.private_module_function(name)
      module_function(name)
      private_class_method(name)
    end

    case RUBY_CONFIG["host_os"] || ::RUBY_PLATFORM
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      # Detect Windows system
      #
      # @return [Boolean]
      #
      # @!visibility private
      def windows?
        true
      end
    else
      # Detect Windows system
      #
      # @return [Boolean]
      #
      # @!visibility private
      def windows?
        false
      end
    end
    module_function :windows?

    case RUBY_CONFIG["ruby_install_name"] || ::RUBY_ENGINE
    when /jruby/
      # Detect JRuby
      #
      # @return [Boolean]
      #
      # @!visibility private
      def jruby?
        true
      end
    else
      # Detect JRuby
      #
      # @return [Boolean]
      #
      # @!visibility private
      def jruby?
        false
      end
    end
    module_function :jruby?

    # The default terminal screen size
    #
    # @return [Array(Integer, Integer)]
    #
    # @api private
    DEFAULT_SIZE = [27, 80].freeze

    @env = ENV
    @output = $stderr

    class << self
      # The environment variables
      #
      # @example
      #   TTY::Screen.env
      #
      # @example
      #   TTY::Screen.env = {"ROWS" => "51", "COLUMNS" => "211"}
      #
      # @return [Enumerable]
      #
      # @api public
      attr_accessor :env

      # The output stream with standard error as default
      #
      # @example
      #   TTY::Screen.output
      #
      # @example
      #   TTY::Screen.output = $stdout
      #
      # @return [IO]
      #
      # @api public
      attr_accessor :output
    end

    # Detect terminal screen size
    #
    # @example
    #   TTY::Screen.size # => [51, 211]
    #
    # @return [Array(Integer, Integer)]
    #   the terminal screen size
    #
    # @api public
    def size(verbose: false)
      size_from_java(verbose: verbose) ||
        size_from_win_api(verbose: verbose) ||
        size_from_ioctl ||
        size_from_io_console(verbose: verbose) ||
        size_from_readline(verbose: verbose) ||
        size_from_tput ||
        size_from_stty ||
        size_from_env ||
        size_from_ansicon ||
        size_from_default
    end

    module_function :size

    # Detect terminal screen width
    #
    # @example
    #   TTY::Screen.width # => 211
    #
    # @return [Integer]
    #
    # @api public
    def width
      size[1]
    end

    module_function :width

    alias columns width
    alias cols width
    module_function :columns
    module_function :cols

    # Detect terminal screen height
    #
    # @example
    #   TTY::Screen.height # => 51
    #
    # @return [Integer]
    #
    # @api public
    def height
      size[0]
    end

    module_function :height

    alias rows height
    alias lines height
    module_function :rows
    module_function :lines

    # Detect terminal screen size from default
    #
    # @return [Array(Integer, Integer)]
    #
    # @api private
    def size_from_default
      DEFAULT_SIZE
    end

    module_function :size_from_default

    if windows?
      # The standard output handle
      #
      # @return [Integer]
      #
      # @api private
      STDOUT_HANDLE = 0xFFFFFFF5

      # Detect terminal screen size from Windows API
      #
      # @param [Boolean] verbose
      #   the verbose mode, by default false
      #
      # @return [Array(Integer, Integer), nil]
      #   the terminal screen size or nil
      #
      # @api private
      def size_from_win_api(verbose: false)
        require "fiddle" unless defined?(Fiddle)

        kernel32 = Fiddle::Handle.new("kernel32")
        get_std_handle = Fiddle::Function.new(
          kernel32["GetStdHandle"], [-Fiddle::TYPE_INT], Fiddle::TYPE_INT
        )
        get_console_buffer_info = Fiddle::Function.new(
          kernel32["GetConsoleScreenBufferInfo"],
          [Fiddle::TYPE_LONG, Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT
        )

        format = "SSSSSssssSS"
        buffer = ([0] * format.size).pack(format)
        stdout_handle = get_std_handle.(STDOUT_HANDLE)

        get_console_buffer_info.(stdout_handle, buffer)
        _, _, _, _, _, left, top, right, bottom, = buffer.unpack(format)
        size = [bottom - top + 1, right - left + 1]
        size if nonzero_column?(size[1] - 1)
      rescue LoadError
        warn "no native fiddle module found" if verbose
      rescue Fiddle::DLError
        # non windows platform or no kernel32 lib
      end
    else
      def size_from_win_api(verbose: false)
        nil
      end
    end
    module_function :size_from_win_api

    if jruby?
      # Detect terminal screen size from Java
      #
      # @param [Boolean] verbose
      #   the verbose mode, by default false
      #
      # @return [Array(Integer, Integer), nil]
      #   the terminal screen size or nil
      #
      # @api private
      def size_from_java(verbose: false)
        require "java"

        java_import "jline.TerminalFactory"
        terminal = TerminalFactory.get
        size = [terminal.get_height, terminal.get_width]
        size if nonzero_column?(size[1])
      rescue
        warn "failed to import java terminal package" if verbose
      end
    else
      def size_from_java(verbose: false)
        nil
      end
    end
    module_function :size_from_java

    # Detect terminal screen size from io-console
    #
    # On Windows, the io-console falls back to reading environment
    # variables. This means any user changes to the terminal screen
    # size will not be reflected in the runtime of the Ruby application.
    #
    # @param [Boolean] verbose
    #   the verbose mode, by default false
    #
    # @return [Array(Integer, Integer), nil]
    #   the terminal screen size or nil
    #
    # @api private
    def size_from_io_console(verbose: false)
      return unless output.tty?

      require "io/console" unless IO.method_defined?(:winsize)
      return unless output.respond_to?(:winsize)

      size = output.winsize
      size if nonzero_column?(size[1])
    rescue Errno::EOPNOTSUPP
      # no support for winsize on output
    rescue LoadError
      warn "no native io/console support or io-console gem" if verbose
    end

    module_function :size_from_io_console

    if !jruby? && output.respond_to?(:ioctl)
      # The get window size control code for Linux
      #
      # @return [Integer]
      #
      # @api private
      TIOCGWINSZ = 0x5413

      # The get window size control code for FreeBSD and macOS
      #
      # @return [Integer]
      #
      # @api private
      TIOCGWINSZ_PPC = 0x40087468

      # The get window size control code for Solaris
      #
      # @return [Integer]
      #
      # @api private
      TIOCGWINSZ_SOL = 0x5468

      # The ioctl window size buffer format
      #
      # @return [String]
      #
      # @api private
      TIOCGWINSZ_BUF_FMT = "SSSS"
      private_constant :TIOCGWINSZ_BUF_FMT

      # The ioctl window size buffer length
      #
      # @return [Integer]
      #
      # @api private
      TIOCGWINSZ_BUF_LEN = TIOCGWINSZ_BUF_FMT.length
      private_constant :TIOCGWINSZ_BUF_LEN

      # Detect terminal screen size from ioctl
      #
      # @return [Array(Integer, Integer), nil]
      #   the terminal screen size or nil
      #
      # @api private
      def size_from_ioctl
        buffer = Array.new(TIOCGWINSZ_BUF_LEN, 0).pack(TIOCGWINSZ_BUF_FMT)

        if ioctl?(TIOCGWINSZ, buffer) ||
           ioctl?(TIOCGWINSZ_PPC, buffer) ||
           ioctl?(TIOCGWINSZ_SOL, buffer)
          rows, cols, = buffer.unpack(TIOCGWINSZ_BUF_FMT)
          [rows, cols] if nonzero_column?(cols)
        end
      end

      # Check if the ioctl call gets window size on any standard stream
      #
      # @param [Integer] control
      #   the control code
      # @param [String] buf
      #   the window size buffer
      #
      # @return [Boolean]
      #   true if the ioctl call gets window size, false otherwise
      #
      # @api private
      def ioctl?(control, buf)
        ($stdout.ioctl(control, buf) >= 0) ||
          ($stdin.ioctl(control, buf) >= 0) ||
          ($stderr.ioctl(control, buf) >= 0)
      rescue SystemCallError
        false
      end

      module_function :ioctl?
    else
      def size_from_ioctl; nil end
    end
    module_function :size_from_ioctl

    # Detect terminal screen size from readline
    #
    # @param [Boolean] verbose
    #   the verbose mode, by default false
    #
    # @return [Array(Integer, Integer), nil]
    #   the terminal screen size or nil
    #
    # @api private
    def size_from_readline(verbose: false)
      return unless output.tty?

      require "readline" unless defined?(::Readline)
      return unless ::Readline.respond_to?(:get_screen_size)

      size = ::Readline.get_screen_size
      size if nonzero_column?(size[1])
    rescue LoadError
      warn "no readline gem" if verbose
    rescue NotImplementedError
    end

    module_function :size_from_readline

    # Detect terminal screen size from tput
    #
    # @return [Array(Integer, Integer), nil]
    #   the terminal screen size or nil
    #
    # @api private
    def size_from_tput
      return unless output.tty? && command_exist?("tput")

      lines = run_command("tput", "lines")
      return unless lines

      cols = run_command("tput", "cols")
      [lines.to_i, cols.to_i] if nonzero_column?(cols)
    end

    module_function :size_from_tput

    # Detect terminal screen size from stty
    #
    # @return [Array(Integer, Integer), nil]
    #   the terminal screen size or nil
    #
    # @api private
    def size_from_stty
      return unless output.tty? && command_exist?("stty")

      out = run_command("stty", "size")
      return unless out

      size = out.split.map(&:to_i)
      size if nonzero_column?(size[1])
    end

    module_function :size_from_stty

    # Detect terminal screen size from environment variables
    #
    # After executing Ruby code, when the user changes terminal
    # screen size during code runtime, the code will not be
    # notified, and hence will not see the new size reflected
    # in its copy of LINES and COLUMNS environment variables.
    #
    # @return [Array(Integer, Integer), nil]
    #   the terminal screen size or nil
    #
    # @api private
    def size_from_env
      return unless env["COLUMNS"] =~ /^\d+$/

      size = [(env["LINES"] || env["ROWS"]).to_i, env["COLUMNS"].to_i]
      size if nonzero_column?(size[1])
    end

    module_function :size_from_env

    # Detect terminal screen size from the ANSICON environment variable
    #
    # @return [Array(Integer, Integer), nil]
    #   the terminal screen size or nil
    #
    # @api private
    def size_from_ansicon
      return unless env["ANSICON"] =~ /\((.*)x(.*)\)/

      size = [::Regexp.last_match(2).to_i, ::Regexp.last_match(1).to_i]
      size if nonzero_column?(size[1])
    end

    module_function :size_from_ansicon

    # Check if a command exists
    #
    # @param [String] command
    #   the command to check
    #
    # @return [Boolean]
    #
    # @api private
    def command_exist?(command)
      exts = env.fetch("PATHEXT", "").split(::File::PATH_SEPARATOR)
      env.fetch("PATH", "").split(::File::PATH_SEPARATOR).any? do |dir|
        file = ::File.join(dir, command)
        ::File.exist?(file) ||
          exts.any? { |ext| ::File.exist?("#{file}#{ext}") }
      end
    end

    private_module_function :command_exist?

    # Run command capturing the standard output
    #
    # @param [Array<String>] args
    #   the command arguments
    #
    # @return [String, nil]
    #   the command output or nil
    #
    # @api private
    def run_command(*args)
      %x(#{args.join(" ")})
    rescue IOError, SystemCallError
      nil
    end

    private_module_function :run_command

    # Check if a number is non-zero
    #
    # @param [Integer, String] column
    #   the column to check
    #
    # @return [Boolean]
    #
    # @api private
    def nonzero_column?(column)
      column.to_i > 0
    end

    private_module_function :nonzero_column?
  end

  # A class responsible for finding an executable in the PATH
  module Which
    # Find an executable in a platform independent way
    #
    # @param [String] cmd
    #   the command to search for
    # @param [Array<String>] paths
    #   the paths to look through
    #
    # @example
    #   which("ruby")                 # => "/usr/local/bin/ruby"
    #   which("/usr/local/bin/ruby")  # => "/usr/local/bin/ruby"
    #   which("foo")                  # => nil
    #
    # @example
    #   which("ruby", paths: ["/usr/locale/bin", "/usr/bin", "/bin"])
    #
    # @return [String, nil]
    #   the absolute path to executable if found, `nil` otherwise
    #
    # @api public
    def which(cmd, paths: search_paths)
      if file_with_path?(cmd)
        return cmd if executable_file?(cmd)

        extensions.each do |ext|
          exe = "#{cmd}#{ext}"
          return ::File.absolute_path(exe) if executable_file?(exe)
        end
        return nil
      end

      paths.each do |path|
        if file_with_exec_ext?(cmd)
          exe = ::File.join(path, cmd)
          return ::File.absolute_path(exe) if executable_file?(exe)
        end
        extensions.each do |ext|
          exe = ::File.join(path, "#{cmd}#{ext}")
          return ::File.absolute_path(exe) if executable_file?(exe)
        end
      end
      nil
    end

    module_function :which

    # Check if executable exists in the path
    #
    # @param [String] cmd
    #   the executable to check
    #
    # @param [Array<String>] paths
    #   paths to check
    #
    # @return [Boolean]
    #
    # @api public
    def exist?(cmd, paths: search_paths)
      !which(cmd, paths: paths).nil?
    end

    module_function :exist?

    # Find default system paths
    #
    # @param [String] path
    #   the path to search through
    #
    # @example
    #   search_paths("/usr/local/bin:/bin")
    #   # => ["/bin"]
    #
    # @return [Array<String>]
    #   the array of paths to search
    #
    # @api private
    def search_paths(path = ENV["PATH"])
      paths = if path && !path.empty?
          path.split(::File::PATH_SEPARATOR)
        else
          %w[/usr/local/bin /usr/ucb /usr/bin /bin]
        end
      paths.select(&Dir.method(:exist?))
    end

    module_function :search_paths

    # All possible file extensions
    #
    # @example
    #   extensions(".exe;cmd;.bat")
    #   # => [".exe", ".bat"]
    #
    # @param [String] path_ext
    #   a string of semicolon separated filename extensions
    #
    # @return [Array<String>]
    #   an array with valid file extensions
    #
    # @api private
    def extensions(path_ext = ENV["PATHEXT"])
      return [""] unless path_ext

      path_ext.split(::File::PATH_SEPARATOR).select { |part| part.include?(".") }
    end

    module_function :extensions

    # Determines if filename is an executable file
    #
    # @example Basic usage
    #   executable_file?("/usr/bin/less") # => true
    #
    # @example Executable in directory
    #   executable_file?("less", "/usr/bin") # => true
    #   executable_file?("less", "/usr") # => false
    #
    # @param [String] filename
    #   the path to file
    # @param [String] dir
    #   the directory within which to search for filename
    #
    # @return [Boolean]
    #
    # @api private
    def executable_file?(filename, dir = nil)
      path = ::File.join(dir, filename) if dir
      path ||= filename
      ::File.file?(path) && ::File.executable?(path)
    end

    module_function :executable_file?

    # Check if command itself has executable extension
    #
    # @param [String] filename
    #   the path to executable file
    #
    # @example
    #   file_with_exec_ext?("file.bat")
    #   # => true
    #
    # @return [Boolean]
    #
    # @api private
    def file_with_exec_ext?(filename)
      extension = ::File.extname(filename)
      return false if extension.empty?

      extensions.any? { |ext| extension.casecmp(ext).zero? }
    end

    module_function :file_with_exec_ext?

    # Check if executable file is part of absolute/relative path
    #
    # @param [String] cmd
    #   the executable to check
    #
    # @return [Boolean]
    #
    # @api private
    def file_with_path?(cmd)
      ::File.expand_path(cmd) == cmd
    end

    module_function :file_with_path?
  end # Which
end # TTY

##
## module for terminal output
##
module CLI
  # String helpers
  # @api public
  class ::String
    ##
    ## Truncate a string at the end, accounting for message prefix
    ##
    ## @param      prefix  [Integer] The length of the prefix
    ##
    def trunc(prefix = 8)
      if length > TTY::Screen.cols - prefix
        self[0..TTY::Screen.cols - prefix]
      else
        self
      end
    end

    #---------------------------------------------------------------------------
    ## Destructive version of #trunc
    ##
    ## @param      prefix  [Integer] The length of the prefix
    ##
    ## @return     [String] truncated string
    ##
    def trunc!(prefix)
      replace trunc(prefix)
    end
  end

  class << self
    # Enable coloring
    attr_writer :coloring
    # Enable debugging
    attr_writer :debug

    ## Basic ANSI color codes
    COLORS = {
      black: 30,
      red: 31,
      green: 32,
      yellow: 33,
      cyan: 36,
      white: 37,
      default: 39,
    }.freeze

    ## Basic ANSI style codes
    FORMATS = {
      reset: 0,
      bold: 1,
      dark: 2,
      italic: 3,
      underline: 4,
      underscore: 4,
      blink: 5,
      rapid_blink: 6,
      negative: 7,
    }.freeze

    ##
    ## Convert symbol to ansi code based on table
    ##
    ## @param      color  [Symbol, String] The color
    ## @param      style  [Array<Symbol>] The style, :bold, :dark, etc.
    ##
    def to_ansi(color, style = [:normal])
      return "" unless @coloring

      style = [style] unless style.is_a?(Array)
      prefix = style.map { |s| "#{FORMATS[s.to_sym]};" }.join
      "\033[#{prefix}#{COLORS[color.to_sym]}m"
    end

    ##
    ## Send ansi code for resetting cursor to beginning of current line
    ##
    def reset_line
      "\033\[A" if @coloring
    end

    ##
    ## Send ansi code for clearing the current line
    ##
    def kill_line
      "\033\[2K" if @coloring
    end

    ##
    ## Send ansi code for reset to regular text
    ##
    def reset
      to_ansi(:default, :reset)
    end

    ##
    ## Send ansi code for bold white text
    ##
    def white
      to_ansi(:white, :bold)
    end

    ##
    ## Display alert level message. Ignored unless debugging is active
    ##
    ## @param      message  [String] The message
    ##
    def debug(message)
      warn "#{kill_line}#{to_ansi(:white, :dark)}DEBUG: #{message.trunc}#{reset}\n" if @debug
    end

    ##
    ## Display error level message
    ##
    ## @param      message  [String] The message
    ##
    def error(message)
      warn "\n#{to_ansi(:red, :bold)}ERROR: #{white}#{message.trunc}#{reset}\n"
    end

    ##
    ## Display alert level message
    ##
    ## @param      message  [String] The message
    ##
    def alert(message)
      warn "#{kill_line}#{to_ansi(:yellow, :bold)}ALERT: #{white}#{message.trunc}#{reset}\n"
    end

    ##
    ## Display completion message
    ##
    ## @param      message  [String] The message
    ##
    def finished(message)
      warn "#{kill_line}#{to_ansi(:cyan, :bold)}FINISHED: #{white}#{message.trunc(10)}#{reset}\n"
    end

    ##
    ## Display info message. Formats as white if coloring is enabled, resets to
    ## beginning of line unless debugging
    ##
    ## @param      message  [String] The message
    ##
    def info(message)
      warn "#{kill_line}#{white} INFO: #{message.trunc}#{reset_line unless @debug}"
    end
  end
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
    @content = content ? content : ""
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
    row.split("|").map(&:strip)[1..-1]
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
      string.ljust(width, " ")
    when :right
      string.rjust(width, " ")
    when :center
      string.center(width, " ")
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

    @string << "|"
    row.zip(@widths).each do |cell, width|
      width = @max_cell_width - 2 if width >= @max_cell_width
      if width.zero?
        @string << "|"
      else
        content = @alignment ? align(@alignment[idx], cell, width) : cell.ljust(width, " ")
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
    @string << "|"
    return unless @alignment

    @alignment.zip(@widths).each do |align, width|
      @string << ":" if align == :left
      width = @max_cell_width - 2 if width >= @max_cell_width
      @string << "-" * (width + (align == :center ? 2 : 1))
      @string << ":" if align == :right
      @string << "|"
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
      "#{m[1]}\n#{"|" * cells}\n"
    end

    tables = @content.to_enum(:scan, table_rx).map { Regexp.last_match }

    tables.each do |t|
      table = []

      if t["align"].nil?
        cells = parse_cells(t["header"])
        align = "|#{([":---"] * cells.count).join("|")}|"
      else
        align = t["align"]
      end

      next unless parse_cells(align.ensure_pipes)

      @alignment = parse_cells(align.ensure_pipes).map do |cell|
        if cell[0, 1] == ":" && cell[-1, 1] == ":"
          :center
        elsif cell[-1, 1] == ":"
          :right
        else
          :left
        end
      end

      lines = t["table"].split(/\n/)
      lines.delete_if(&:alignment?)

      lines.each do |row|
        # Ensure leading and trailing pipes
        row = row.ensure_pipes

        cells = parse_cells(row)

        table << cells
      end

      @content.sub!(/#{Regexp.escape(t["table"])}/, "#{build_table(table)}\n")
    end

    @content
  end
end

##
## Class for converting HTML to Markdown using Nokogiri
##
## @api public
##
class HTML2Markdown
  def initialize(str, baseurl = nil)
    begin
      require "nokogiri"
    rescue LoadError
      puts "Nokogiri not installed. Please run `gem install --user-install nokogiri` or `sudo gem install nokogiri`."
      Process.exit 1
    end

    @links = []
    @baseuri = (baseurl ? URI.parse(baseurl) : nil)
    @section_level = 0
    @encoding = str.encoding
    @markdown = output_for(Nokogiri::HTML(str, baseurl).root).gsub(/\n+/, "\n")
  end

  ##
  ## Output conversion, adding stored links in reference format.
  ##
  ## @return     [String] String representation of the object.
  ##
  def to_s
    i = 0
    "#{@markdown}\n\n" + @links.map do |link|
      i += 1
      "[#{i}]: #{link[:href]}" + (link[:title] ? " (#{link[:title]})" : "")
    end.join("\n")
  end

  ##
  ## Output all children for the node
  ##
  ## @param      node  [Nokogiri] the Nokogiri node to process
  ##
  ## @see        #output_for
  ##
  ## @return     output of node's children
  ##
  def output_for_children(node)
    node.children.map { |el| output_for(el) }.join
  end

  ##
  ## Add link to the stored links for outut later
  ##
  ## @param      link  [Hash] The link (:href) and title (:title)
  ##
  ## @return     [Integer] length of links hash
  ##
  def add_link(link)
    if @baseuri
      begin
        link[:href] = URI.parse(link[:href])
      rescue StandardError
        link[:href] = URI.parse("")
      end
      link[:href].scheme = @baseuri.scheme unless link[:href].scheme
      unless link[:href].opaque
        link[:href].host = @baseuri.host unless link[:href].host
        link[:href].path = "#{@baseuri.path}/#{link[:href].path}" if link[:href].path.to_s[0] != "/"
      end
      link[:href] = link[:href].to_s
    end
    @links.each_with_index do |l, i|
      return i + 1 if l[:href] == link[:href]
    end
    @links << link
    @links.length
  end

  ##
  ## Wrap string respecting word boundaries
  ##
  ## @param      str   [String]   The string to wrap
  ##
  ## @return     [String] wrapped string
  ##
  def wrap(str)
    return str if str =~ /\n/

    out = []
    line = []
    str.split(/[ \t]+/).each do |word|
      line << word
      if line.join(" ").length >= 74
        out << line.join(" ") << " \n"
        line = []
      end
    end
    out << line.join(" ") + (str[-1..-1] =~ /[ \t\n]/ ? str[-1..-1] : "")
    out.join
  end

  ##
  ## Output for a single node
  ##
  ## @param      node [Nokogiri]  The Nokogiri node object
  ##
  ## @return [String] outut of node
  ##
  def output_for(node)
    case node.name
    when "head", "style", "script"
      ""
    when "br"
      " "
    when "p", "div"
      "\n\n#{wrap(output_for_children(node))}\n\n"
    when "section", "article"
      @section_level += 1
      o = "\n\n----\n\n#{output_for_children(node)}\n\n"
      @section_level -= 1
      o
    when /h(\d+)/
      "\n\n#{"#" * (Regexp.last_match(1).to_i + @section_level)} #{output_for_children(node)}\n\n"
    when "blockquote"
      @section_level += 1
      o = "\n\n> #{wrap(output_for_children(node)).gsub(/\n/, "\n> ")}\n\n".gsub(/> \n(> \n)+/, "> \n")
      @section_level -= 1
      o
    when "ul"
      "\n\n" + node.children.map do |el|
        next if el.name == "text" || el.text.strip.empty?

        "- #{output_for_children(el).gsub(/^(\t)|(    )/, "\t\t").gsub(/^>/, "\t>")}\n"
      end.join + "\n\n"
    when "ol"
      i = 0
      "\n\n" + node.children.map { |el|
        next if el.name == "text" || el.text.strip.empty?

        i += 1
        "#{i}. #{output_for_children(el).gsub(/^(\t)|(    )/, "\t\t").gsub(/^>/, "\t>")}\n"
      }.join + "\n\n"
    when "code"
      block = "\t#{wrap(output_for_children(node)).gsub(/\n/, "\n\t")}"
      if block.count("\n").zero?
        "`#{output_for_children(node)}`"
      else
        block
      end
    when "hr"
      "\n\n----\n\n"
    when "a", "link"
      link = { href: node["href"], title: node["title"] }
      "[#{output_for_children(node).gsub("\n", " ")}][#{add_link(link)}]"
    when "img"
      link = { href: node["src"], title: node["title"] }
      "![#{node["alt"]}][#{add_link(link)}]"
    when "video", "audio", "embed"
      link = { href: node["src"], title: node["title"] }
      "[#{output_for_children(node).gsub("\n", " ")}][#{add_link(link)}]"
    when "object"
      link = { href: node["data"], title: node["title"] }
      "[#{output_for_children(node).gsub("\n", " ")}][#{add_link(link)}]"
    when "i", "em", "u"
      "_#{node.text.sub(/(\s*)?$/, '_\1')}"
    when "b", "strong"
      "**#{node.text.sub(/(\s*)?$/, '**\1')}"
      # Tables are not part of Markdown, so we output WikiCreole
    when "table"
      @first_row = true
      output_for_children(node)
    when "tr"
      ths = node.children.select { |c| c.name == "th" }
      tds = node.children.select { |c| c.name == "td" }
      if ths.count > 1 && tds.count.zero?
        output = node.children.select { |c| c.name == "th" }
                     .map { |c| output_for(c) }
                     .join.gsub(/\|\|/, "|")
        align = node.children.select { |c| c.name == "th" }
                    .map { ":---|" }
                    .join
        output = "#{output}\n|#{align}"
      else
        els = node.children.select { |c| c.name == "th" || c.name == "td" }
        output = els.map { |cell| output_for(cell) }.join.gsub(/\|\|/, "|")
      end
      @first_row = false
      output
    when "th", "td"
      if node.name == "th" && !@first_row
        "|**#{clean_cell(output_for_children(node).strip)}**|"
      else
        "|#{clean_cell(output_for_children(node).strip)}|"
      end
    when "text"
      # Sometimes Nokogiri lies. Force the encoding back to what we know it is
      if (c = node.content.force_encoding(@encoding)) =~ /\S/
        c.gsub(/\n\n+/, "<$PreserveDouble$>")
         .gsub(/\s+/, " ")
         .gsub(/<\$PreserveDouble\$>/, "\n\n")
      else
        c
      end
    else
      wrap(output_for_children(node))
    end
  end

  ##
  ## Remove HTML tags from a table cell
  ##
  ## @param      content  [String] The cell content
  ##
  ## @return     [String] the cleaned content
  ##
  def clean_cell(content)
    content.gsub!(%r{</?p>}, "")
    content.gsub!(%r{<li>(.*?)</li>}m, "- \\1\n")
    content.gsub!(%r{<(\w+)(?: .*?)?>(.*?)</\1>}m, '\2')
    content.gsub!(%r{\n-\s*\n}m, "")
    content.gsub(/\n+/, "<br/>")
  end
end

# Main Confluence to Markdown class
# @api public
class Confluence2MD
  ##
  ## Initialize a new Confluence2MD object
  ##
  ## @param      options  [Hash] The options
  ##
  def initialize(options = {})
    defaults = {
      clean_dirs: false,
      clean_tables: false,
      escape: true,
      fix_headers: true,
      fix_hierarchy: true,
      fix_tables: false,
      include_source: false,
      max_table_width: nil,
      max_cell_width: 30,
      rename_files: true,
      strip_emoji: true,
      strip_meta: false,
      update_links: true,
    }
    @options = defaults.merge(options)
    CLI.debug = options[:debug] || false
    CLI.coloring = options[:color] ? true : false
  end

  ## Locate Pandoc executable
  ##
  ## @return     [String] path to pandoc executable
  ##
  def pandoc
    @pandoc ||= "pandoc"

    ## This method causes errors on Windows
    # @pandoc ||= begin
    #     unless TTY::Which.exist?("pandoc")
    #       CLI.error "Pandoc not found. Please install pandoc and ensure it is in your PATH."
    #       Process.exit 1
    #     end
    #     TTY::Which.which("pandoc")
    #   end
  end

  ##
  ## Pandoc options
  ##
  ## @param      additional  [Array] array of additional
  ##                         options
  ##
  ## @return     [String] all options as a command line string
  ##
  def pandoc_options(additional)
    additional = [additional] if additional.is_a?(String)
    [
      "--wrap=none",
      "-f html",
      "-t markdown_strict+rebase_relative_paths",
    ].concat(additional).join(" ")
  end

  ##
  ## Copy attachments folder to markdown/
  ##
  def copy_attachments(markdown_dir)
    target = File.expand_path("attachments")

    target = File.expand_path("images/attachments") unless File.directory?(target)
    unless File.directory?(target)
      CLI.alert "Attachments directory not found #{target}"
      return
    end

    FileUtils.cp_r(target, markdown_dir)
    CLI.info "Copied #{target.trunc_middle(60)} to #{markdown_dir}"
  end

  ##
  ## Flatten the attachments folder and move contents to images/
  ##
  def flatten_attachments
    target = File.expand_path("attachments")

    target = File.expand_path("images/attachments") unless File.directory?(target)
    unless File.directory?(target)
      CLI.alert "Attachments directory not found #{target}"
      return
    end

    copied = 0

    Dir.glob("**/*", base: target).each do |file|
      next unless file =~ /(png|jpe?g|gif|pdf|svg)$/

      file = File.join(target, file)

      CLI.debug "Copying #{file} to #{File.join("markdown/images", File.basename(file))}"
      FileUtils.cp file, File.join("markdown/images", File.basename(file))
      copied += 1
    end

    CLI.info "Copied #{copied} files from attachments to images"
  end

  ##
  ## Delete images/images folder if it exists
  ##
  def clean_images_folder
    folder = File.expand_path("images/images")
    if File.directory?(folder)
      CLI.alert "Deleting images/images folder"
      FileUtils.rm_rf(folder)
    end
  end

  ##
  ## Convert all HTML files in current directory to Markdown. Creates
  ## directories for stripped HTML and markdown output, with subdirectory for
  ## extracted images.
  ##
  def all_html
    stripped_dir = File.expand_path("stripped")
    markdown_dir = File.expand_path("markdown")

    if @options[:clean_dirs]
      CLI.alert "Cleaning out markdown directories"

      # Clear out previous runs
      FileUtils.rm_rf(stripped_dir) if File.exist?(stripped_dir)
      FileUtils.rm_rf(markdown_dir) if File.exist?(markdown_dir)
    end
    FileUtils.mkdir_p(stripped_dir)
    FileUtils.mkdir_p(File.join(markdown_dir, "images"))

    if @options[:flatten_attachments]
      flatten_attachments
    else
      copy_attachments(markdown_dir)
    end

    index_h = {}
    counter = 0

    Dir.glob("*.html") do |html|
      counter += 1
      content = IO.read(html)
      basename = File.basename(html, ".html")
      stripped = File.join("stripped", "#{basename}.html")

      markdown = if @options[:rename_files]
          title = content.match(%r{<title>(.*?)</title>}m)[1]
                         .sub(/^.*? : /, "").sub(/👓/, "").sub(/copy of /i, "")
          File.join("markdown", "#{title.slugify}.md")
        else
          File.join("markdown", "#{basename}.md")
        end
      content.prepare_content!(@options)

      File.open(stripped, "w") { |f| f.puts content }

      res, err, status = Open3.capture3(%(#{pandoc} #{pandoc_options("--extract-media markdown/images")} "#{stripped}"))
      unless status.success?
        CLI.error("Failed to run pandoc on #{File.basename(stripped)}")
        CLI.debug err
        next
      end

      CLI.info("#{html.trunc_middle(60)} => #{markdown.trunc_middle(60)}")
      res = "#{res}\n\n<!--Source: #{html}-->\n" if @options[:include_source]
      res = res.fix_tables if @options[:fix_tables]

      res.relative_paths!
      res.strip_comments!
      res.markdownify_images!
      res.fix_numbered_list_indent!
      if @options[:clean_tables] && @options[:fix_tables]
        tc = TableCleanup.new(res)
        tc.max_cell_width = @options[:max_cell_width] if @options[:max_cell_width]
        tc.max_table_width = @options[:max_table_width] if @options[:max_table_width]
        res = tc.clean
      end

      res.repoint_flattened! if @options[:flatten_attachments]
      res.unescape_markdown! unless @options[:escape]

      index_h[File.basename(html)] = File.basename(markdown)
      File.open(markdown, "w") { |f| f.puts res }
    end

    # Update local HTML links to Markdown filename
    update_links(index_h) if @options[:rename_files] && @options[:update_links]
    # Delete interim HTML directory
    FileUtils.rm_f("stripped")
    clean_images_folder
    CLI.finished "Processed #{counter} files"
  end

  ##
  ## Update local links based on dictionary. Rewrites Markdown files in place.
  ##
  ## @param      index_h  [Hash] dictionary of filename mappings { [html_filename] = markdown_filename }
  ##
  def update_links(index_h)
    Dir.chdir("markdown")
    Dir.glob("*.md").each do |file|
      content = IO.read(file)
      index_h.each do |html, markdown|
        target = markdown.sub(/\.md$/, ".html")
        content.gsub!(/(?<!Source: )#{html}/, target)
      end
      File.open(file, "w") { |f| f.puts content }
    end
  end

  ##
  ## Convert a single HTML file passed by path on the command line. Returns
  ## Markdown result as string for output to STDOUT.
  ##
  ## @param      html  [String] the HTML file path
  ##
  ## @return     [String] The Markdown result
  ##
  def single_file(html)
    content = IO.read(html)

    markdown = if @options[:rename_files]
        title = content.match(%r{<title>(.*?)</title>}m)[1]
                       .sub(/^.*? : /, "").sub(/👓/, "").sub(/copy of /i, "")
        "#{title.slugify}.md"
      end

    content.prepare_content!(@options)

    res, err, status = Open3.capture3(%(echo #{Shellwords.escape(content)} | pandoc #{pandoc_options("--extract-media images")}))
    unless status.success?
      CLI.error("Failed to run pandoc on #{File.basename(stripped)}")
      CLI.debug err
      return nil
    end

    res = "#{res}\n\n<!--Source: #{html}-->\n" if @options[:include_source]
    res = res.fix_tables if @options[:fix_tables]
    if @options[:clean_tables] && @options[:fix_tables]
      tc = TableCleanup.new(res)
      tc.max_cell_width = @options[:max_cell_width] if @options[:max_cell_width]
      tc.max_table_width = @options[:max_table_width] if @options[:max_table_width]
      res = tc.clean
    end
    res.fix_numbered_list_indent!
    res.unescape_markdown! unless @options[:escape]
    return res.relative_paths.strip_comments unless markdown

    CLI.info "#{html.trunc_middle(60)} => #{markdown}"
    File.open(markdown, "w") { |f| f.puts res.relative_paths.strip_comments }
    nil
  end

  ##
  ## Handle input from pipe and convert to Markdown
  ##
  ## @param      content  [String] The HTML input
  ##
  ## @return     [String] Markdown output
  ##
  def handle_stdin(content)
    content.prepare_content!(@options)
    content = Shellwords.escape(content)

    res, err, status = Open3.capture3(%(echo #{content} | pandoc #{pandoc_options("--extract-media images")}))
    unless status.success?
      CLI.error "Failed to run pandoc on STDIN"
      CLI.debug err
      return nil
    end

    res = res.fix_tables if @options[:fix_tables]
    if @options[:clean_tables] && @options[:fix_tables]
      tc = TableCleanup.new(res)
      tc.max_cell_width = @options[:max_cell_width] if @options[:max_cell_width]
      tc.max_table_width = @options[:max_table_width] if @options[:max_table_width]
      res = tc.clean
    end
    res.fix_numbered_list_indent!
    res.unescape_markdown! unless @options[:escape]
    res.relative_paths.strip_comments
  end

  # string helpers
  class ::String
    ##
    ## Remove unnecessary backslashes from Markdown output
    ##
    ## @return     [String] cleaned up string
    ##
    def unescape_markdown
      gsub(/\\([<>\\`*_\[\]#@|^~$\-"' l;])/, '\1')
    end

    ##
    ## Compress whitespace after numbers in numbered lists
    ##
    def fix_numbered_list_indent
      gsub(/(^[ \t]*\d\.)\s+/, '\1 ')
    end

    ##
    ## Destructive version of #fix_numbered_list_indent
    ## @see #fix_numbered_list_indent
    def fix_numbered_list_indent!
      replace fix_numbered_list_indent
    end

    ##
    ## Destructive version of #unescape_markdown
    ## @see #unescape_markdown
    def unescape_markdown!
      replace unescape_markdown
    end

    ##
    ## Truncate string in middle
    ##
    ## @param      length  [Integer] final length of string
    ##
    ## @return     [String] truncated string
    ##
    def trunc_middle(length)
      string = dup

      return string if string.length <= length

      start_length = (length - 5) / 2
      end_length = length - start_length - 5

      "#{string[0, start_length]}[...]#{string[-end_length, end_length]}"
    end

    ##
    ## Convert a string to hyphenated slug
    ##
    ## @return     [String] slug version
    ##
    def slugify
      downcase.gsub(/[^a-z0-9]/, "-").gsub(/-+/, "-").gsub(/(^-|-$)/, "")
    end

    ##
    ## Remove emojis from output
    ##
    ## @return     [String] string with emojis stripped
    ##
    def strip_emoji
      text = dup.force_encoding("utf-8").encode

      # symbols & pics
      regex = /[\u{1f300}-\u{1f5ff}]/
      clean = text.gsub(regex, "")

      # enclosed chars
      regex = /[\u{2500}-\u{2BEF}]/
      clean = clean.gsub(regex, "")

      # emoticons
      regex = /[\u{1f600}-\u{1f64f}]/
      clean = clean.gsub(regex, "")

      # dingbats
      regex = /[\u{2702}-\u{27b0}]/
      clean = clean.gsub(regex, "")
    end

    ##
    ## Destructive version of #strip_emoji
    ## @see        #strip_emoji
    ##
    ## @return     [String] string with emoji stripped
    ##
    def strip_emoji!
      replace strip_emoji
    end

    ##
    ## Strips out Confluence detritus like TOC and author metadata
    ##
    ## @return     [String] string with metadata cleaned out
    ##
    def strip_meta
      content = dup
      # Remove style tags and content
      content.sub!(%r{<style.*?>.*?</style>}m, "")
      # Remove TOC
      content.gsub!(%r{<div class='toc-macro.*?</div>}m, "")

      # Match breadcrumb-section
      breadcrumbs = content.match(%r{<div id="breadcrumb-section">(.*?)</div>}m)
      if breadcrumbs
        # Extract page title from breadcrumbs
        page_title = breadcrumbs[1].match(%r{<li class="first">.*?<a href="index.html">(.*?)</a>}m)
        if page_title
          page_title = page_title[1]
          content.sub!(breadcrumbs[0], "")
          # find header
          header = content.match(%r{<div id="main-header">(.*?)</div>}m)

          old_title = header[1].match(%r{<span id="title-text">(.*?)</span>}m)[1].strip
          # Replace header with title we found as H1
          content.sub!(header[0], "<h1>#{old_title.sub(/#{page_title} : /, "").sub(/copy of /i, "")}</h1>")
        end
      end

      # Remove entire page-metadata block
      content.sub!(%r{<div class="page-metadata">.*?</div>}m, "")
      # Remove footer elements (attribution)
      content.sub!(%r{<div id="footer-logo">.*?</div>}m, "")
      content.sub!(%r{<div id="footer" role="contentinfo">.*?</div>}m, "")

      content
    end

    ##
    ## Count the number of h1 headers in the document
    ##
    ## @return     Number of h1s.
    ##
    def count_h1s
      scan(/<h1.*?>/).count
    end

    ##
    ## Bump all headers except for first H1
    ##
    ## @return     Content with adjusted headers
    ##
    def fix_headers
      return self if count_h1s == 1

      first_h1 = true

      gsub(%r{<h([1-6]).*?>(.*?)</h\1>}m) do
        m = Regexp.last_match
        level = m[1].to_i
        content = m[2].strip
        if level == 1 && first_h1
          first_h1 = false
          m[0]
        else
          level += 1 if level < 6

          "<h#{level}>#{content}</h#{level}>"
        end
      end
    end

    ##
    ## Adjust header levels so there's no jump greater than 1
    ##
    ## @return     Content with adjusted headers
    ##
    def fix_hierarchy
      headers = to_enum(:scan, %r{<h([1-6]).*?>(.*?)</h\1>}m).map { Regexp.last_match }
      content = dup
      last = 1
      headers.each do |h|
        level = h[1].to_i
        if level <= last + 1
          last = level
          next
        end

        level = last + 1
        content.sub!(/#{Regexp.escape(h[0])}/, "<h#{level}>#{h[2]}</h#{level}>")
      end

      content
    end

    ##
    ## Use nokogiri to convert tables
    ##
    ## @return     Content with tables markdownified
    ##
    def fix_tables
      gsub(%r{<table.*?>.*?</table>}m) do
        m = Regexp.last_match
        HTML2Markdown.new(m[0]).to_s.fix_indentation
      end.gsub(/\|\n\[/, "|\n\n[")
    end

    ##
    ## Make indentation of subsequent lines match the first line
    ##
    ## @return     [String] Outdented version of text
    ##
    def fix_indentation
      return self unless strip =~ (/^\s+\S/)
      out = []
      lines = split(/\n/)
      lines.delete_if { |l| l.strip.empty? }
      indent = lines[0].match(/^(\s*)\S/)[1]
      indent ||= ""

      lines.each do |line|
        next if line.strip.empty?

        out << line.sub(/^\s*/, indent)
      end

      "\n#{out.join("\n")}\n"
    end

    ##
    ## Clean up HTML before Markdown conversion. Removes block elements
    ## (div/section) and inline elements (span), fixes links and images, removes
    ## zero-width spaces
    ##
    ## @return     [String] cleaned up HTML string
    ##
    def cleanup
      content = dup
      # Checkmarks
      content.gsub!(%r{<span class="emoji">✔️</span>}, "&#10003;")

      # admonitions

      content.gsub!(%r{(?mix)
        <div\sclass="confluence-information-macro\sconfluence-information-macro-(.*?)">
        <p\sclass="title\sconf-macro-render">(.*?)</p>}) do
        m = Regexp.last_match
        if m[1] =~ /tip/
          "<p><em>#{m[2]}:</em></p>"
        else
          "<p><strong>#{m[2]}:</strong></p>"
        end
      end

      # delete div, section, and span tags (preserve content)
      content.gsub!(%r{</?div.*?>}m, "")
      content.gsub!(%r{</?section.*?>}m, "")
      content.gsub!(%r{</?span.*?>}m, "")
      # delete additional attributes on links (pandoc outputs weird syntax for attributes)
      content.gsub!(/<a.*?(href=".*?").*?>/, '<a \1>')
      # Delete icons
      content.gsub!(/<img class="icon".*?>/m, "")
      # Convert embedded images to easily-matched syntax for later replacement
      content.gsub!(/<img.*class="confluence-embedded-image.*?".*?src="(.*?)".*?>/m, '%image: \1')
      # Rewrite img tags with just src, converting data-src to src
      content.gsub!(%r{<img.*? src="(.*?)".*?/?>}m, '<img src="\1">')
      content.gsub!(%r{<img.*? data-src="(.*?)".*?/?>}m, '<img src="\1">')
      # Remove confluenceTd from tables
      content.gsub!(/ class="confluenceTd" /, "")
      # Remove emphasis tags around line breaks
      content.gsub!(%r{<(em|strong|b|u|i)><br/></\1>}m, "<br/>")
      # Remove empty emphasis tags
      content.gsub!(%r{<(em|strong|b|u|i)>\s*?</\1>}m, "")
      # Convert <br></strong> to <strong><br>
      content.gsub!(%r{<br/></strong>}m, "</strong><br/>")
      # Remove zero-width spaces and empty spans
      content.gsub!(%r{<span>\u00A0</span>}, " ")
      content.gsub!(/\u00A0/, " ")
      content.gsub!(%r{<span> *</span>}, " ")
      # Remove squares from lists
      content.gsub!(/■/, "")
      # remove empty tags
      # content.gsub!(%r{<(\S+).*?>([\n\s]*?)</\1>}, '\2')
      content
    end

    ##
    ## Change image paths to correct relative path
    ##
    ## @return     [String] image paths replaced
    ##
    def relative_paths
      gsub(%r{markdown/images/}, "images/")
    end

    ##
    ## Destructive version of #relative_paths
    ## @see        #relative_paths
    ##
    ## @return     [String] image paths replaced
    ##
    def relative_paths!
      replace relative_paths
    end

    ##
    ## Comment/span stripping
    ##
    ## @return     [String] comments stripped
    ##
    def strip_comments
      # Remove empty comments and spans
      gsub(/\n+ *<!-- *-->\n/, "").gsub(%r{</?span.*?>}m, "")
    end

    ##
    ## Destructive comment/span strip
    ## @see        #strip_comments
    ##
    ## @return     [String] comments stripped
    ##
    def strip_comments!
      replace strip_comments
    end

    ##
    ## Repoint images to flattened folder
    ##
    ## @return [String] content with /attachments links updated
    ##
    def repoint_flattened
      gsub(%r{(?:images/)?attachments/(?:\d+)/(.*?(?:png|jpe?g|gif|pdf))}, 'images/\1')
    end

    ##
    ## Destructive version of repoint_flattened
    ## @see #repoint_flattened
    ##
    ## @return [String] content with /attachments links updated
    ##
    def repoint_flattened!
      replace repoint_flattened
    end

    ##
    ## Replace %image with Markdown format
    ##
    ## @return     [String] content with markdownified images
    ##
    def markdownify_images
      gsub(/%image: (.*?)$/) do
        # URL-encode image path
        m = Regexp.last_match
        "![](#{m[1]})"
      end
    end

    ##
    ## Destructive version of markdownify_images
    ## @see #markdownify_images
    ##
    ## @return     [String] content with markdownified images
    ##
    def markdownify_images!
      replace markdownify_images
    end

    ##
    ## Process HTML content based on options
    ##
    ## @param      options  [Hash] The options
    ##
    ## @return [String] processed content
    ##
    def prepare_content(options)
      content = dup
      content = content.strip_meta if options[:strip_meta]
      content = content.cleanup
      content = content.strip_emoji if options[:strip_emoji]
      content = content.fix_headers if options[:fix_headers]
      content = content.fix_hierarchy if options[:fix_hierarchy]
      content
    end

    ##
    ## Destructive version of #prepare_content
    ##
    ## @param      options  [Hash] The options
    ##
    ## @return [String] processed content
    ##
    def prepare_content!(options)
      replace prepare_content(options)
    end
  end
end

options = {
  clean_dirs: false,
  clean_tables: true,
  color: true,
  debug: false,
  escape: true,
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

  opt.on("--[no-]escape", "Escape special characters (default true)") do |option|
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
