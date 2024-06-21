#!/usr/bin/env ruby -W1
# frozen_string_literal: true

# Requirements:
#   Ruby 3.x
#   Pandoc installed in $PATH

require 'fileutils'
require 'shellwords'
require 'optparse'

class Confluence2MD
  attr_writer :strip_meta, :strip_emoji, :clean_dirs,
              :include_source, :update_links, :rename_files

  def initialize
    @strip_meta = false
    @strip_emoji = true
    @clean_dirs = false
    @include_source = false
    @update_links = true
    @rename_files = true
  end

  ##
  ## Convert all HTML files in current directory to Markdown. Creates
  ## directories for stripped HTML and markdown output, with subdirectory for
  ## extracted images.
  ##
  ## Currently fails to extract images because they're behind authentication.
  ## I'm not sure if Confluence is able to include attached images in HTML
  ## output, but I see that as the only way to make this work.
  ##
  def all_html
    if @clean_dirs
      # Clear out previous runs
      FileUtils.rm_f('stripped') if File.exist?('stripped')
      FileUtils.rm_f('markdown') if File.exist?('markdown')
    end
    FileUtils.mkdir_p('stripped')
    FileUtils.mkdir_p('markdown/images')

    index_h = {}

    Dir.glob('*.html') do |html|
      content = IO.read(html)
      basename = File.basename(html, '.html')
      stripped = File.join('stripped', "#{basename}.html")

      markdown = if @rename_files
                   title = content.match(%r{<title>(.*?)</title>}m)[1].sub(/^.*? : /, '').sub(/👓/, '').sub(/copy of /i, '')
                   File.join('markdown', "#{title.slugify}.md")
                 else
                   File.join('markdown', "#{basename}.md")
                 end

      content = content.strip_meta if @strip_meta
      content = content.cleanup
      content = content.strip_emoji if @strip_emoji

      File.open(stripped, 'w') { |f| f.puts content }

      res = `pandoc --wrap=none --extract-media markdown/images -f html -t markdown_strict+rebase_relative_paths "#{stripped}"`
      warn "#{html} => #{markdown}"
      res = "#{res}\n\n<!--Source: #{html}-->\n" if @include_source

      res.relative_paths!
      res.strip_comments!
      res.markdownify_images!

      index_h[File.basename(html)] = File.basename(markdown)
      File.open(markdown, 'w') { |f| f.puts res }
    end

    # Update local HTML links to Markdown filename
    update_links(index_h) if @rename_files && @update_links
    # Delete interim HTML directory
    FileUtils.rm_f('stripped')
  end

  ##
  ## Update local links based on dictionary. Rewrites Markdown files in place.
  ##
  ## @param      index_h  [Hash] dictionary of filename mappings { [html_filename] = markdown_filename }
  ##
  def update_links(index_h)
    Dir.chdir('markdown')
    Dir.glob('*.md').each do |file|
      content = IO.read(file)
      index_h.each do |html, markdown|
        target = markdown.sub(/\.md$/, '.html')
        content.gsub!(/(?<!Source: )#{html}/, target)
      end
      File.open(file, 'w') { |f| f.puts content }
    end
  end

  ##
  ## Convert a single HTML file passed by path on the command line. Returns
  ## Markdown result as string for output to STDOUT.
  ##
  ## @param      [String]  The Markdown result
  ##
  def single_file(html)
    content = IO.read(html)

    content = content.strip_meta if @strip_meta
    content = content.cleanup
    content = content.strip_emoji if @strip_emoji

    res = `echo #{Shellwords.escape(content)} | pandoc --wrap=none --extract-media images -f html -t markdown_strict+rebase_relative_paths`
    res = "#{res}\n\n<!--Source: #{html}-->\n" if @include_source
    res.relative_paths.strip_comments
  end

  ##
  ## Handle input from pipe and convert to Markdown
  ##
  ## @param      input  [String] The HTML input
  ##
  ## @return     [String] Markdown output
  ##
  def handle_stdin(input)
    input = input.strip_meta if @strip_meta
    input = input.cleanup
    input = input.strip_emoji if @strip_emoji

    res = `echo #{Shellwords.escape(input)} | pandoc --wrap=none --extract-media images -f html -t markdown_strict+rebase_relative_paths`
    res.relative_paths.strip_comments
  end

  # string helpers
  class ::String
    ##
    ## Convert a string to hyphenated slug
    ##
    ## @return     [String] slug version
    ##
    def slugify
      downcase.gsub(/[^a-z0-9]/, '-').gsub(/-+/, '-').gsub(/(^-|-$)/, '')
    end

    ##
    ## Remove emojis from output
    ##
    ## @return     [String] string with emojis stripped
    ##
    def strip_emoji
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
      content.sub!(%r{<style.*?>.*?</style>}m, '')
      content.gsub!(%r{<div class='toc-macro.*?</div>}m, '')

      breadcrumbs = content.match(%r{<div id="breadcrumb-section">(.*?)</div>}m)
      if breadcrumbs
        page_title = breadcrumbs[1].match(%r{<li class="first">.*?<a href="index.html">(.*?)</a>}m)
        if page_title
          page_title = page_title[1]
          content.sub!(breadcrumbs[0], '')
          header = content.match(%r{<div id="main-header">(.*?)</div>}m)

          old_title = header[1].match(%r{<span id="title-text">(.*?)</span>}m)[1].strip
          content.sub!(header[0], "<h1>#{old_title.sub(/#{page_title} : /, '').sub(/copy of /i, '')}</h1>")
        end
      end

      content.sub!(%r{<div class="page-metadata">.*?</div>}m, '')

      content.sub!(%r{<div id="footer-logo">.*?</div>}m, '')
      content.sub!(%r{<div id="footer" role="contentinfo">.*?</div>}m, '')

      content
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
      content.gsub!(%r{</?div.*?>}m, '')
      content.gsub!(%r{</?section.*?>}m, '')
      content.gsub!(%r{</?span.*?>}m, '')
      content.gsub!(/<(a href=".*?").*?>/, '<\1>')
      content.gsub!(/<img class="icon".*?>/m, '')
      content.gsub!(%r{<img.*class="confluence-embedded-image.*?".*title="(.*?)">}m, "\n%image: \\1\n")
      content.gsub!(%r{<img.*? src="(.*?)".*?/?>}m, '<img src="\1">')
      content.gsub!(%r{<img.*? data-src="(.*?)".*?/?>}m, '<img src="\1">')
      content.gsub!(/ class="confluenceTd" /, '')
      content.gsub!(%r{<span>\u00A0</span>}, ' ')
      content.gsub!(/\u00A0/, ' ')
      content.gsub!(%r{<span> *</span>}, ' ')
      content.gsub!(/■/, '')
      content
    end

    ##
    ## Change image paths to correct relative path
    ##
    ## @return     [String] image paths replaced
    ##
    def relative_paths
      gsub(%r{markdown/images/}, 'images/')
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
      gsub(/\n+ *<!-- *-->\n/, '').gsub(%r{</?span.*?>}m, '')
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
    ## Replace %image with Markdown format
    ##
    ## @return     [String] content with markdownified images
    ##
    def markdownify_images
      gsub(/%image: (.*?)$/, '![](\1)')
    end

    def markdownify_images!
      replace markdownify_images
    end
  end
end

options = {
  strip_meta: false,
  strip_emoji: true,
  clean_dirs: false,
  rename_files: true,
  source: false,
  update_links: true
}

opt_parser = OptionParser.new do |opt|
  opt.banner = <<~EOBANNER
    Run in a folder full of HTML files, or pass a single HTML file as argument"
    Usage: #{File.basename(__FILE__)} [OPTIONS] [FILE]
  EOBANNER
  opt.separator  ''
  opt.separator  'Options:'

  opt.on('-c', '--clean', 'Clear output directories before converting') do
    options[:clean_dirs] = true
  end

  opt.on('-s', '--strip-meta', 'Strip Confluence metadata (default false)') do
    options[:strip_meta] = true
  end

  opt.on('-e', '--[no-]strip-emoji', 'Strip emoji (default true)') do |opt|
    options[:strip_emoji] = opt
  end

  opt.on('--[no-]rename', 'Rename output files based on page title (default true)') do |opt|
    options[:rename_files] = opt
  end

  opt.on('--[no-]source', 'Include an HTML comment with name of original HTML file (default false)') do |opt|
    options[:source] = opt
  end

  opt.on('--[no-]update-links', 'Update links to local files (default true)') do |opt|
    options[:update_links] = opt
  end
end

opt_parser.parse!

c2m = Confluence2MD.new
c2m.strip_meta = options[:strip_meta]
c2m.strip_emoji = options[:strip_emoji]
c2m.clean_dirs = options[:clean_dirs]
c2m.include_source = options[:source]
c2m.update_links = options[:update_links]
c2m.rename_files = options[:rename_files]

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
