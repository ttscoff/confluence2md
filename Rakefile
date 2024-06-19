require 'rake/clean'
require 'rdoc'
require 'rdoc/task'
require 'yard'

YARD::Rake::YardocTask.new do |t|
 t.files = ['*.rb']
 t.options = ['--markup-provider=redcarpet', '--markup=markdown', '--no-private', '-p', 'yard_templates']
 # t.stats_options = ['--list-undoc']
end

task :doc, [*Rake.application[:yard].arg_names] => [:yard]

Rake::RDocTask.new do |rd|
  rd.main = 'README.md'
  rd.rdoc_files.include('README.md', '*.rb')
  rd.title = 'confluence2md'
  rd.markup = 'markdown'
end

desc 'Bump incremental version number'
task :bump, :type do |_, args|
  args.with_defaults(type: 'inc')
  version_file = 'VERSION'
  content = IO.read(version_file)
  content.sub!(/(?<major>\d+)\.(?<minor>\d+)\.(?<inc>\d+)(?<pre>\S+)?/) do
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
