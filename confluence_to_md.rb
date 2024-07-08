#!/usr/bin/env ruby -W1
# frozen_string_literal: true

# Requirements:
#   Ruby 3.x
#   Pandoc installed in $PATH

require 'fileutils'
require 'shellwords'
require 'optparse'
require 'erb'

class Confluence2MD
  # Preference to delete output directories
  attr_writer :clean_dirs
  # Preference to strip metadata
  attr_writer :strip_meta
  # Preference to strip emoji
  attr_writer :strip_emoji
  # Preference to rename files to title slug
  attr_writer :rename_files
  # Preference to update local links to markdown slugs
  attr_writer :update_links
  # Preference to include source comment in markdown output
  attr_writer :include_source
  # Preference to fix headers
  attr_writer :fix_headers
  # Preference to fix hierarchy
  attr_writer :fix_hierarchy
  # VERSION number
  attr_reader :version

  def initialize
    @strip_meta = false
    @strip_emoji = true
    @clean_dirs = false
    @include_source = false
    @update_links = true
    @rename_files = true
    @fix_headers = true
    @fix_hierarchy = true
    @version = get_version
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
      content = content.fix_headers if @fix_headers
      content = content.fix_hierarchy if @fix_hierarchy

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
    content = content.fix_headers if @fix_headers
    content = content.fix_hierarchy if @fix_hierarchy

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
    input = input.fix_headers if @fix_headers
    input = input.fix_hierarchy if @fix_hierarchy

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
      # Remove style tags and content
      content.sub!(%r{<style.*?>.*?</style>}m, '')
      # Remove TOC
      content.gsub!(%r{<div class='toc-macro.*?</div>}m, '')

      # Match breadcrumb-section
      breadcrumbs = content.match(%r{<div id="breadcrumb-section">(.*?)</div>}m)
      if breadcrumbs
        # Extract page title from breadcrumbs
        page_title = breadcrumbs[1].match(%r{<li class="first">.*?<a href="index.html">(.*?)</a>}m)
        if page_title
          page_title = page_title[1]
          content.sub!(breadcrumbs[0], '')
          # find header
          header = content.match(%r{<div id="main-header">(.*?)</div>}m)

          old_title = header[1].match(%r{<span id="title-text">(.*?)</span>}m)[1].strip
          # Replace header with title we found as H1
          content.sub!(header[0], "<h1>#{old_title.sub(/#{page_title} : /, '').sub(/copy of /i, '')}</h1>")
        end
      end

      # Remove entire page-metadata block
      content.sub!(%r{<div class="page-metadata">.*?</div>}m, '')
      # Remove footer elements (attribution)
      content.sub!(%r{<div id="footer-logo">.*?</div>}m, '')
      content.sub!(%r{<div id="footer" role="contentinfo">.*?</div>}m, '')

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
    ## Clean up HTML before Markdown conversion. Removes block elements
    ## (div/section) and inline elements (span), fixes links and images, removes
    ## zero-width spaces
    ##
    ## @return     [String] cleaned up HTML string
    ##
    def cleanup
      content = dup
      # delete div, section, and span tags (preserve content)
      content.gsub!(%r{</?div.*?>}m, '')
      content.gsub!(%r{</?section.*?>}m, '')
      content.gsub!(%r{</?span.*?>}m, '')
      # delete additional attributes on links (pandoc outputs weird syntax for attributes)
      content.gsub!(/<a.*?(href=".*?").*?>/, '<a \1>')
      # Delete icons
      content.gsub!(/<img class="icon".*?>/m, '')
      # Convert embedded images to easily-matched syntax for later replacement
      content.gsub!(%r{<img.*class="confluence-embedded-image.*?".*title="(.*?)">}m, "\n%image: \\1\n")
      # Rewrite img tags with just src, converting data-src to src
      content.gsub!(%r{<img.*? src="(.*?)".*?/?>}m, '<img src="\1">')
      content.gsub!(%r{<img.*? data-src="(.*?)".*?/?>}m, '<img src="\1">')
      # Remove confluenceTd from tables
      content.gsub!(/ class="confluenceTd" /, '')
      # Remove zero-width spaces and empty spans
      content.gsub!(%r{<span>\u00A0</span>}, ' ')
      content.gsub!(/\u00A0/, ' ')
      content.gsub!(%r{<span> *</span>}, ' ')
      # Remove squares from lists
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
      gsub(/%image: (.*?)$/) do
        # URL-encode image path
        m = Regexp.last_match
        url = ERB::Util.url_encode(m[1])
        "![](#{url})"
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
  end

  private

  def get_version
    version_file = File.join(File.dirname(File.realdirpath(__FILE__)), 'VERSION')
    if File.exist?(version_file)
      version = IO.read(version_file).strip
      "v#{version}"
    else
      '(version unavailable)'
    end
  end
end

options = {
  clean_dirs: false,
  fix_headers: true,
  fix_hierarchy: true,
  rename_files: true,
  source: false,
  strip_emoji: true,
  strip_meta: false,
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

  opt.on('-f', '--[no-]fix-headers', 'Bump all headers except first h1 (default true)') do |option|
    options[:fix_headers] = option
  end

  opt.on('-o', '--[no-]fix-hierarchy', 'Fix header nesting order (default true)') do |option|
    options[:fix_hierarchy] = option
  end

  opt.on('-e', '--[no-]strip-emoji', 'Strip emoji (default true)') do |option|
    options[:strip_emoji] = option
  end

  opt.on('--[no-]rename', 'Rename output files based on page title (default true)') do |option|
    options[:rename_files] = option
  end

  opt.on('--[no-]source', 'Include an HTML comment with name of original HTML file (default false)') do |option|
    options[:source] = option
  end

  opt.on('--[no-]update-links', 'Update links to local files (default true)') do |option|
    options[:update_links] = option
  end

  opt.on('-v', '--version', 'Display version number') do
    c2m = Confluence2MD.new
    puts "#{File.basename(__FILE__)} #{c2m.version}"
    Process.exit 0
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
c2m.fix_headers = options[:fix_headers]
c2m.fix_hierarchy = options[:fix_hierarchy]

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
