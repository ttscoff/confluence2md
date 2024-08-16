# frozen_string_literal: true

# Main Confluence to Markdown class
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
      fix_headers: true,
      fix_hierarchy: true,
      fix_tables: false,
      include_source: false,
      max_table_width: nil,
      max_cell_width: 30,
      rename_files: true,
      strip_emoji: true,
      strip_meta: false,
      update_links: true
    }
    @options = defaults.merge(options)
    CLI.debug = options[:debug] || false
    CLI.coloring = options[:color] ? true : false
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
      '--wrap=none',
      '-f html',
      '-t markdown_strict+rebase_relative_paths'
    ].concat(additional).join(' ')
  end

  ##
  ## Copy attachments folder to markdown/
  ##
  def copy_attachments(markdown_dir)
    target = File.expand_path('attachments')

    target = File.expand_path('images/attachments') unless File.directory?(target)
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
    target = File.expand_path('attachments')

    target = File.expand_path('images/attachments') unless File.directory?(target)
    unless File.directory?(target)
      CLI.alert "Attachments directory not found #{target}"
      return
    end

    copied = 0

    Dir.glob('**/*', base: target).each do |file|
      next unless file =~ /(png|jpe?g|gif|pdf|svg)$/

      file = File.join(target, file)

      CLI.debug "Copying #{file} to #{File.join('markdown/images', File.basename(file))}"
      FileUtils.cp file, File.join('markdown/images', File.basename(file))
      copied += 1
    end

    CLI.info "Copied #{copied} files from attachments to images"
  end

  ##
  ## Delete images/images folder if it exists
  ##
  def clean_images_folder
    folder = File.expand_path('images/images')
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
    stripped_dir = File.expand_path('stripped')
    markdown_dir = File.expand_path('markdown')

    if @options[:clean_dirs]
      CLI.alert "Cleaning out markdown directories"

      # Clear out previous runs
      FileUtils.rm_rf(stripped_dir) if File.exist?(stripped_dir)
      FileUtils.rm_rf(markdown_dir) if File.exist?(markdown_dir)
    end
    FileUtils.mkdir_p(stripped_dir)
    FileUtils.mkdir_p(File.join(markdown_dir, 'images'))

    if @options[:flatten_attachments]
      flatten_attachments
    else
      copy_attachments(markdown_dir)
    end

    index_h = {}
    counter = 0

    Dir.glob('*.html') do |html|
      counter += 1
      content = IO.read(html)
      basename = File.basename(html, '.html')
      stripped = File.join('stripped', "#{basename}.html")

      markdown = if @options[:rename_files]
                   title = content.match(%r{<title>(.*?)</title>}m)[1]
                                  .sub(/^.*? : /, '').sub(/👓/, '').sub(/copy of /i, '')
                   File.join('markdown', "#{title.slugify}.md")
                 else
                   File.join('markdown', "#{basename}.md")
                 end
      content.prepare_content!(@options)

      File.open(stripped, 'w') { |f| f.puts content }

      res, err, status = Open3.capture3(%(pandoc #{pandoc_options('--extract-media markdown/images')} "#{stripped}"))
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
      if @options[:clean_tables] && @options[:fix_tables]
        tc = TableCleanup.new(res)
        tc.max_cell_width = @options[:max_cell_width] if @options[:max_cell_width]
        tc.max_table_width = @options[:max_table_width] if @options[:max_table_width]
        res = tc.clean
      end

      res.repoint_flattened! if @options[:flatten_attachments]

      index_h[File.basename(html)] = File.basename(markdown)
      File.open(markdown, 'w') { |f| f.puts res }
    end

    # Update local HTML links to Markdown filename
    update_links(index_h) if @options[:rename_files] && @options[:update_links]
    # Delete interim HTML directory
    FileUtils.rm_f('stripped')
    clean_images_folder
    CLI.finished "Processed #{counter} files"
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
  ## @param      html  [String] the HTML file path
  ##
  ## @return     [String] The Markdown result
  ##
  def single_file(html)
    content = IO.read(html)

    markdown = if @options[:rename_files]
                 title = content.match(%r{<title>(.*?)</title>}m)[1]
                                .sub(/^.*? : /, '').sub(/👓/, '').sub(/copy of /i, '')
                 "#{title.slugify}.md"
               end

    content.prepare_content!(@options)

    res, err, status = Open3.capture3(%(echo #{Shellwords.escape(content)} | pandoc #{pandoc_options('--extract-media images')}))
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
    return res.relative_paths.strip_comments unless markdown

    CLI.info "#{html.trunc_middle(60)} => #{markdown}"
    File.open(markdown, 'w') { |f| f.puts res.relative_paths.strip_comments }
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

    res, err, status = Open3.capture3(%(echo #{content} | pandoc #{pandoc_options('--extract-media images')}))
    unless status.success?
      CLI.error 'Failed to run pandoc on STDIN'
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
    res.relative_paths.strip_comments
  end

  # string helpers
  class ::String
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
      clean = clean.gsub(regex, '')
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
      indent ||= ''

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
      content.gsub!(%r{<span class="emoji">✔️</span>}, '&#10003;')

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
      content.gsub!(%r{</?div.*?>}m, '')
      content.gsub!(%r{</?section.*?>}m, '')
      content.gsub!(%r{</?span.*?>}m, '')
      # delete additional attributes on links (pandoc outputs weird syntax for attributes)
      content.gsub!(/<a.*?(href=".*?").*?>/, '<a \1>')
      # Delete icons
      content.gsub!(/<img class="icon".*?>/m, '')
      # Convert embedded images to easily-matched syntax for later replacement
      content.gsub!(/<img.*class="confluence-embedded-image.*?".*?src="(.*?)".*?>/m, '%image: \1')
      # Rewrite img tags with just src, converting data-src to src
      content.gsub!(%r{<img.*? src="(.*?)".*?/?>}m, '<img src="\1">')
      content.gsub!(%r{<img.*? data-src="(.*?)".*?/?>}m, '<img src="\1">')
      # Remove confluenceTd from tables
      content.gsub!(/ class="confluenceTd" /, '')
      # Remove emphasis tags around line breaks
      content.gsub!(%r{<(em|strong|b|u|i)><br/></\1>}m, '<br/>')
      # Remove empty emphasis tags
      content.gsub!(%r{<(em|strong|b|u|i)>\s*?</\1>}m, '')
      # Convert <br></strong> to <strong><br>
      content.gsub!(%r{<br/></strong>}m, '</strong><br/>')
      # Remove zero-width spaces and empty spans
      content.gsub!(%r{<span>\u00A0</span>}, ' ')
      content.gsub!(/\u00A0/, ' ')
      content.gsub!(%r{<span> *</span>}, ' ')
      # Remove squares from lists
      content.gsub!(/■/, '')
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

  ##
  ## Return script version (requires it be run from within repository where VERSION file exists)
  ##
  ## @return     [String] version string
  ##
  def version
    version_file = File.join(File.dirname(File.realdirpath(__FILE__)), 'VERSION')
    if File.exist?(version_file)
      version = IO.read(version_file).strip
      "v#{version}"
    else
      '(version unavailable)'
    end
  end
end
