#!/usr/bin/env ruby

# Script to concat files to a config file.
#
# Given a directory like this:
# /path/to/conf.d
# |-- fragments
# |   |-- 00_named.conf
# |   |-- 10_domain.net
# |   `-- zz_footer
#
# The script supports a test option that will build the concat file to a temp location and
# use /usr/bin/cmp to verify if it should be run or not.  This would result in the concat happening
# twice on each run but gives you the option to have an unless option in your execs to inhibit rebuilds
#
# Without the test option and the unless combo your services that depend on the final file would end up
# restarting on each run, or in other manifest models some changes might get missed.
#
# OPTIONS:
#  -o	The file to create from the sources
#  -d	The directory where the fragments are kept
#  -t	Test to find out if a build is needed, basically concats the files to a temp
#       location and compare with what's in the final location, return codes are designed
#       for use with unless on an exec resource
#  -w   Add a shell style comment at the top of the created file to warn users that it
#       is generated by puppet
#  -f   Enables the creation of empty output files when no fragments are found
#  -s   Where to find the sort utility, defaults to /bin/sort
#  -n	Sort the output numerically rather than the default alpha sort
#
# the command:
#
#   concatfragments.sh -o /path/to/conffile.cfg -d /path/to/conf.d
#
# creates /path/to/conf.d/fragments.concat and copies the resulting
# file to /path/to/conffile.cfg.  The files will be sorted alphabetically
# pass the -n switch to sort numerically.
#
# The script does error checking on the various dirs and files to make
# sure things don't fail.

require 'optparse'
require 'fileutils'
require 'logger'

log = Logger.new("C:/Users/Administrator/Documents/concat_log")
log.level = Logger::DEBUG

log.debug '--START--'
log.debug ARGV

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: concatfragments.rb -o outputfile -d workdirectory [-t] [-f] [-w]'

  options[:outfile] = nil
  opts.on('-o', '--outfile FILE', 'Output File') do |o|
    options[:outfile] = o
  end

  options[:workdir] = nil
  opts.on('-d', '--workdir FILE', 'Work Directory') do |o|
    options[:workdir] = o
  end

  opts.on('-n', '--numericalsort', 'Sort Numerically (depreciated)') do |o|
    options[:sortarg] = '-zn'
  end

  opts.on('-s', '--sort', 'Sort Command (depreciated)') do |o|
    options[:sort] = o
  end

  opts.on('-w', '--warn', 'Warn') do |warn|
    options[:warn] = true
  end

  opts.on('-f', '--force', 'Force') do |force|
    options[:force] = true
  end

  options[:test] = false
  opts.on('-t', '--test', 'Test') do |test|
    options[:test] = true
  end
  opts.on('-n', '--notest', 'No Test') do |test|
    options[:test] = false
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end

end.parse!

if ! options[:outfile] or options[:outfile] == ''
  puts 'Please specify an output file with -o'
  exit 1
end

#log = Logger.new("C:/Users/Administrator/Documents/concat_log-#{options[:outfile].gsub('/', '_').gsub('\\', '_').gsub(':', '_')}")
log.debug options.inspect

if ! options[:workdir] or options[:workdir] == ''
  puts 'Please specify a fragments directory with -d'
  exit 1
end

if File.exists? options[:outfile]
  if ! File.writable? options[:outfile]
    puts "Cannot write to #{options[:outfile]}"
    exit 1
  end
else
  if ! File.writable? File.dirname(options[:outfile])
    puts "Cannot write to #{File.dirname(options[:outfile])} to create #{options[:outfile]}"
    exit 1
  end
end

if ! File.directory? "#{options[:workdir]}/fragments"
  puts 'Cannot access the fragments directory'
  exit 1
end

files = Dir.entries("#{options[:workdir]}/fragments")
files = files - ['.', '..']

if files.length == 0
  if options[:force] != true
    puts 'The fragments directory is empty, cowardly refusing to make empty config files'
    exit 1
  end
end

File.open("#{options[:workdir]}/fragments.concat","w"){|f|
  f.puts '#This file is managed by Puppet. DO NOT EDIT.' if options[:warn] == true
  f.puts files.sort.map{|s| IO.read("#{options[:workdir]}/fragments/#{s}")}
}

if options[:test] == true
  if File.exists? options[:outfile]
    log.debug "Checking files"
    if FileUtils.identical?(options[:outfile], "#{options[:workdir]}/fragments.concat")
      log.debug "Files identical"
      exit 0
    else
      log.debug "Files differ"
      exit 1
    end
  else
    exit 1
  end
else
  log.debug "Copying file"
  begin
    FileUtils.cp("#{options[:workdir]}/fragments.concat", options[:outfile])
    log.debug "File copied"
    exit 0
  rescue
    log.debug "Copy failed"
    exit 1
  end
end
log.error "Reached end of file: Should not happen."
