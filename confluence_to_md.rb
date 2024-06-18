#!/usr/bin/env ruby -W1
# frozen_string_literal: true

# Requirements:
#   Ruby 3.x
#   Pandoc installed in $PATH

require 'fileutils'
require 'shellwords'
require 'optparse'

# string helpers
class ::String
  def slugify
    downcase.gsub(/[^a-z0-9]/, '-').gsub(/-+/, '-').gsub(/(^-|-$)/, '')
  end

  def strip_emojis
    text = dup.force_encoding('utf-8').encode

    # symbols & pics
    regex = /[\u{1f300}-\u{1f5ff}]/
    clean = text.gsub(regex, '')

    # enclosed chars
    regex = /[\u{2500}-\u{2BEF}]/
    clean = clean.gsub(regex, '')

    # emoticons
    regex = /[\u{1f600}-\u{1f64f}]/
    clean = clean.gsub(regex, '')

    # dingbats
    regex = /[\u{2702}-\u{27b0}]/
    clean.gsub(regex, '')
  end

  def strip_meta
    content = dup
    content.sub!(%r{<style.*?>.*?</style>}m, '')
    content.gsub!(%r{<div class='toc-macro.*?</div>}m, '')

    breadcrumbs = content.match(%r{<div id="breadcrumb-section">(.*?)</div>}m)
    if breadcrumbs
      page_title = breadcrumbs[1].match(%r{<li class="first">.*?<a href="index.html">(.*?)</a>}m)
      if page_title
        content.sub!(breadcrumbs[0], '')
        header = content.match(%r{<div id="main-header">(.*?)</div>}m)

        old_title = header[1].match(%r{<span id="title-text">(.*?)</span>}m)[1].strip
        content.sub!(header[0], "<h1>#{old_title.sub(/#{page_title} : /, '').sub!(/copy of /i, '')}</h1>")
      end
    end

    metadata = content.sub!(%r{<div class="page-metadata">.*?</div>}m, '')

    content.sub!(%r{<div id="footer-logo">.*?</div>}m, '')
    content.sub!(%r{<div id="footer" role="contentinfo">.*?</div>}m, '')

    content
  end

  def cleanup
    content = dup
    content.gsub!(%r{</?div.*?>}m, '')
    content.gsub!(%r{</?section.*?>}m, '')
    content.gsub!(%r{</?span.*?>}m, '')
    content.gsub!(/<(a href=".*?").*?>/, '<\1>')
    content.gsub!(/<img class="icon".*?>/m, '')
    content.gsub!(%r{<img.*? src="(.*?)".*?/?>}m, '<img src="\1">')
    content.gsub!(%r{<img.*? data-src="(.*?)".*?/?>}m, '<img src="\1">')
    content.gsub!(/ class="confluenceTd" /, '')
    content.gsub!(%r{<span>\u00A0</span>}, ' ')
    content.gsub!(/\u00A0/, ' ')
    content.gsub!(%r{<span> *</span>}, ' ')
    content.gsub!(/■/, '')
    content.strip_emojis
  end

  def relative_paths
    gsub(%r{markdown/images/}, 'images/')
  end

  def relative_paths!
    replace relative_paths
  end

  def strip_comments
    # Remove empty comments
    gsub(/\n+ *<!-- *-->\n/, '')
  end

  def strip_comments!
    replace strip_comments
  end
end

class Confluence2MD
  attr_writer :strip_meta

  def initialize
    @strip_meta = false
  end

  def all_html
    FileUtils.mkdir_p('stripped')
    FileUtils.mkdir_p('markdown/images')

    Dir.glob('*.html') do |html|
      content = IO.read(html)
      basename = File.basename(html, '.html')
      stripped = File.join('stripped', "#{basename}.html")

      title = content.match(%r{<title>(.*?)</title>}m)[1].sub(/^.*? : /, '').sub(/👓/, '').sub(/copy of /i, '')

      markdown = File.join('markdown', "#{title.slugify}.markdown")

      content = content.strip_meta if @strip_meta
      content = content.cleanup

      File.open(stripped, 'w') { |f| f.puts content }

      res = `pandoc --wrap=none --extract-media markdown/images -f html -t markdown_strict+rebase_relative_paths "#{stripped}"`
      warn "#{html} => #{markdown}"

      res.relative_paths!
      res.strip_comments!
      File.open(markdown, 'w') { |f| f.puts res }
    end
  end

  def single_file(html)
    content = IO.read(html)

    content = content.strip_meta if @strip_meta
    content = content.cleanup

    res = `echo #{Shellwords.escape(content)} | pandoc --wrap=none --extract-media images -f html -t markdown_strict+rebase_relative_paths`
    res.relative_paths.strip_comments
  end

  def handle_stdin(input)
    input = input.strip_meta if @strip_meta
    input = input.cleanup
    res = `echo #{Shellwords.escape(input)} | pandoc --wrap=none --extract-media images -f html -t markdown_strict+rebase_relative_paths`
    res.relative_paths.strip_comments
  end
end

options = {
  strip_meta: false
}

opt_parser = OptionParser.new do |opt|
  opt.banner = <<~EOBANNER
    Run in a folder full of HTML files, or pass a single HTML file as argument"
    Usage: #{File.basename(__FILE__)} [OPTIONS] [FILE]
  EOBANNER
  opt.separator  ''
  opt.separator  'Options:'

  opt.on('-s', '--strip-meta', 'Strip Confluence metadata') do
    options[:strip_meta] = true
  end
end

opt_parser.parse!

c2m = Confluence2MD.new
c2m.strip_meta = options[:strip_meta]

# If a single file is passed as an argument, process just that file
if ARGV.count.positive?
  puts c2m.single_file(File.expand_path(ARGV[0]))
# If text is piped in, process STDIN
elsif $stdin.stat.size.positive?
  input = $stdin.read.force_encoding('utf-8')
  puts c2m.handle_stdin(input)
# Otherwise, assume we're in a folder full of HTML files
# subfolders for output will be created
# url-based media is downloaded and saved, relative paths are updated
else
  c2m.all_html
end
