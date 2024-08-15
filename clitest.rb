#!/usr/bin/env ruby -W1
# frozen_string_literal: true

##
## module for terminal output
##
module CLI
  class << self
    # Enable coloring
    attr_writer :coloring
    # Enable debugging
    attr_writer :debug

    COLORS = {
      default: 39,
      black: 30,
      red: 31,
      green: 32,
      yellow: 33,
      cyan: 36,
      white: 37
    }.freeze

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

    def to_ansi(color, style = [:normal])
      return '' unless @coloring

      style = [style] unless style.is_a?(Array)
      prefix = style.map { |s| "#{FORMATS[s.to_sym]};" }.join
      "\033[#{prefix}#{COLORS[color.to_sym]}m"
    end

    def reset_line
      "\033\[A" if @coloring
    end

    def kill_line
      "\033\[2K" if @coloring
    end

    def reset
      to_ansi(:default, :reset)
    end

    def white
      to_ansi(:white, :bold)
    end

    def debug(message)
      warn "#{to_ansi(:white, :dark)}DEBUG: #{message}#{reset}" if @debug
    end

    def error(message)
      warn "#{to_ansi(:red, :bold)}ERROR: #{white}#{message}#{reset}"
    end

    def alert(message)
      warn "#{to_ansi(:yellow, :bold)}ALERT: #{white}#{message}#{reset}"
    end

    def finished(message)
      warn "#{to_ansi(:cyan, :bold)}FINISHED: #{white}#{message}#{reset}"
    end

    def info(message)
      warn "#{kill_line}#{white} INFO: #{message}#{reset_line}"
    end
  end
end

CLI.debug = true
CLI.debug "Test debug message 1"
CLI.debug = false
CLI.debug "Test debug message 2"
CLI.alert "Test alert message"
CLI.info "Test info message 1"
CLI.info "Test info message 2"
CLI.error "Test error message"
CLI.finished "Test completion message"
