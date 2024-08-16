require 'rake/clean'
require 'rdoc'
require 'rdoc/task'
require 'yard'

YARD::Rake::YardocTask.new do |t|
  t.files = ['**/*.rb']
  t.options = ['--markup-provider=redcarpet', '--markup=markdown', '--no-private']
  t.stats_options = ['--list-undoc']
end

task :doc, [*Rake.application[:yard].arg_names] => [:yard]

Rake::RDocTask.new do |rd|
  rd.main = 'README.md'
  rd.rdoc_files.include('README.md', '**/*.rb')
  rd.title = 'confluence2md'
  rd.markup = 'markdown'
end

desc 'Merge required files into single script'
task :merge do
  BuildScript.merge('src/confluence_to_md.rb', 'confluence_to_md.rb')
  BuildScript.merge('src/tablecleaner.rb', 'tablecleaner.rb')
end

class BuildScript
  # String helpers
  class ::String
    def import_markers(base)
      gsub(/^# *merge\nrequire(?:_relative)? '(.*?)'\n/) do
        file = Regexp.last_match(1)
        file = File.join(base, "#{file}.rb")

        content = IO.read(file).sub(/^# frozen_string_literal: true\n+/, '')
        content.import_markers(File.dirname(file))
      end
    end

    def import_markers!(base)
      replace import_markers(base)
    end
  end

  class << self
    def compile(file)
      source_file = File.expand_path(file)
      source = IO.read(source_file).strip

      source.import_markers(File.dirname(source_file))
    end

    def merge(source, target)
      script = compile(File.expand_path(source))
      outfile = File.expand_path(target)

      File.open(outfile, 'w') { |f| f.puts script }
      puts "Updated #{target} script"
    end
  end
end

desc 'Bump incremental version number'
task :bump, :type do |_, args|
  args.with_defaults(type: 'inc')
  version_file = 'lib/version.rb'
  content = IO.read(version_file)
  content.sub!(/(?<=VERSION = ')(?<major>\d+)\.(?<minor>\d+)\.(?<inc>\d+)(?<pre>\S+)?(?=')/) do
    m = Regexp.last_match
    major = m['major'].to_i
    minor = m['minor'].to_i
    inc = m['inc'].to_i
    pre = m['pre']

    case args[:type]
    when /^maj/
      major += 1
      minor = 0
      inc = 0
    when /^min/
      minor += 1
      inc = 0
    else
      inc += 1
    end

    $stdout.puts "At version #{major}.#{minor}.#{inc}#{pre}"
    "#{major}.#{minor}.#{inc}#{pre}"
  end
  File.open(version_file, 'w+') { |f| f.puts content }
end
