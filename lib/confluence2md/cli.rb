# frozen_string_literal: true

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
      default: 39
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
      negative: 7
    }.freeze

    ##
    ## Convert symbol to ansi code based on table
    ##
    ## @param      color  [Symbol, String] The color
    ## @param      style  [Array<Symbol>] The style, :bold, :dark, etc.
    ##
    def to_ansi(color, style = [:normal])
      return '' unless @coloring

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
