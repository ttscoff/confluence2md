# frozen_string_literal: true

##
## Class for converting HTML to Markdown using Nokogiri
##
## @api public
##
class HTML2Markdown
  def initialize(str, baseurl = nil)
    begin
      require 'nokogiri'
    rescue LoadError
      puts 'Nokogiri not installed. Please run `gem install --user-install nokogiri` or `sudo gem install nokogiri`.'
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
      "[#{i}]: #{link[:href]}" + (link[:title] ? " (#{link[:title]})" : '')
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
        link[:href] = URI.parse('')
      end
      link[:href].scheme = @baseuri.scheme unless link[:href].scheme
      unless link[:href].opaque
        link[:href].host = @baseuri.host unless link[:href].host
        link[:href].path = "#{@baseuri.path}/#{link[:href].path}" if link[:href].path.to_s[0] != '/'
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
      if line.join(' ').length >= 74
        out << line.join(' ') << " \n"
        line = []
      end
    end
    out << line.join(' ') + (str[-1..-1] =~ /[ \t\n]/ ? str[-1..-1] : '')
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
    when 'head', 'style', 'script'
      ''
    when 'br'
      ' '
    when 'p', 'div'
      "\n\n#{wrap(output_for_children(node))}\n\n"
    when 'section', 'article'
      @section_level += 1
      o = "\n\n----\n\n#{output_for_children(node)}\n\n"
      @section_level -= 1
      o
    when /h(\d+)/
      "\n\n#{'#' * (Regexp.last_match(1).to_i + @section_level)} #{output_for_children(node)}\n\n"
    when 'blockquote'
      @section_level += 1
      o = "\n\n> #{wrap(output_for_children(node)).gsub(/\n/, "\n> ")}\n\n".gsub(/> \n(> \n)+/, "> \n")
      @section_level -= 1
      o
    when 'ul'
      "\n\n" + node.children.map do |el|
        next if el.name == 'text' || el.text.strip.empty?

        "- #{output_for_children(el).gsub(/^(\t)|(    )/, "\t\t").gsub(/^>/, "\t>")}\n"
      end.join + "\n\n"
    when 'ol'
      i = 0
      "\n\n" + node.children.map { |el|
        next if el.name == 'text' || el.text.strip.empty?

        i += 1
        "#{i}. #{output_for_children(el).gsub(/^(\t)|(    )/, "\t\t").gsub(/^>/, "\t>")}\n"
      }.join + "\n\n"
    when 'code'
      block = "\t#{wrap(output_for_children(node)).gsub(/\n/, "\n\t")}"
      if block.count("\n").zero?
        "`#{output_for_children(node)}`"
      else
        block
      end
    when 'hr'
      "\n\n----\n\n"
    when 'a', 'link'
      link = { href: node['href'], title: node['title'] }
      "[#{output_for_children(node).gsub("\n", ' ')}][#{add_link(link)}]"
    when 'img'
      link = { href: node['src'], title: node['title'] }
      "![#{node['alt']}][#{add_link(link)}]"
    when 'video', 'audio', 'embed'
      link = { href: node['src'], title: node['title'] }
      "[#{output_for_children(node).gsub("\n", ' ')}][#{add_link(link)}]"
    when 'object'
      link = { href: node['data'], title: node['title'] }
      "[#{output_for_children(node).gsub("\n", ' ')}][#{add_link(link)}]"
    when 'i', 'em', 'u'
      "_#{node.text.sub(/(\s*)?$/, '_\1')}"
    when 'b', 'strong'
      "**#{node.text.sub(/(\s*)?$/, '**\1')}"
    # Tables are not part of Markdown, so we output WikiCreole
    when 'table'
      @first_row = true
      output_for_children(node)
    when 'tr'
      ths = node.children.select { |c| c.name == 'th' }
      tds = node.children.select { |c| c.name == 'td' }
      if ths.count > 1 && tds.count.zero?
        output = node.children.select { |c| c.name == 'th' }
                     .map { |c| output_for(c) }
                     .join.gsub(/\|\|/, '|')
        align = node.children.select { |c| c.name == 'th' }
                    .map { ':---|' }
                    .join
        output = "#{output}\n|#{align}"
      else
        els = node.children.select { |c| c.name == 'th' || c.name == 'td' }
        output = els.map { |cell| output_for(cell) }.join.gsub(/\|\|/, '|')
      end
      @first_row = false
      output
    when 'th', 'td'
      if node.name == 'th' && !@first_row
        "|**#{clean_cell(output_for_children(node).strip)}**|"
      else
        "|#{clean_cell(output_for_children(node).strip)}|"
      end
    when 'text'
      # Sometimes Nokogiri lies. Force the encoding back to what we know it is
      if (c = node.content.force_encoding(@encoding)) =~ /\S/
        c.gsub(/\n\n+/, '<$PreserveDouble$>')
         .gsub(/\s+/, ' ')
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
    content.gsub!(%r{</?p>}, '')
    content.gsub!(%r{<li>(.*?)</li>}m, "- \\1\n")
    content.gsub!(%r{<(\w+)(?: .*?)?>(.*?)</\1>}m, '\2')
    content.gsub!(%r{\n-\s*\n}m, '')
    content.gsub(/\n+/, '<br/>')
  end
end
