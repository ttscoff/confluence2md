#!/usr/bin/env ruby -W1

require 'fileutils'

dir = 'fileutils_test'
file = 'copy_me.txt'

FileUtils.mkdir_p(dir)
File.open(file, 'w') { |f| f.puts "This should be in two places."}
FileUtils.cp(file, File.join(dir, file))

puts "Result should be a text file called `copy_me.txt` in the current directory
with a copy in a subdirectory called `fileutils_test`"
