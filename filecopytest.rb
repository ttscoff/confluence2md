#!/usr/bin/env ruby -W1
# frozen_string_literal: true

require 'fileutils'

##
## Flatten the attachments folder and move contents to images/
##
def flatten_attachments
  target = File.expand_path('attachments')

  unless File.directory?(target)
    puts "Directory not found"
    return
  end
  # return unless File.directory?('images/attachments')

  copied = 0

  Dir.glob('**/*', base: target).each do |file|
    next unless file =~ /(png|jpe?g|gif|pdf|svg)$/

    file = File.join(target, file)

    puts "Copying #{file} to #{File.join('markdown/images', File.basename(file))}"
    FileUtils.cp file, File.join('markdown/images', File.basename(file))
    copied += 1
  end

  puts "Copied #{copied} files from attachments to images"
end

flatten_attachments
