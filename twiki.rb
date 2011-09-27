#!/usr/bin/env ruby

require 'directory_watcher'
require 'eventmachine'
#require 'github/markup'
require 'redcarpet'
require 'fileutils'

pid_file='.pid'

if File.exists?(pid_file)
  pid=File.read(pid_file).to_i
  begin
    Process.kill(0, pid)
    puts "Another instance of twiki already running"
    exit
  rescue Errno::ESRCH
  end
end

puts "Creating a new process"
File.open(pid_file,"w+") {|f| f.puts $$}

def process_file(src,dest)
  puts "processing #{src} => #{dest}"
  dir=File.dirname(dest)
  # puts "creating #{dir}"
  FileUtils.mkdir_p(dir)
  File.open(dest,  "w+") do |f|
    f.write File.read("./template/header.html").sub(/<!--BASE-->/,"<base href='#{dest}'/>").sub(/--CSS--/,File.expand_path("template/twiki.css")).sub(/--INDEX--/,File.expand_path("html/index.html"))
#    f.write GitHub::Markup.render(src)
    markdown = RedcarpetCompat.new(File.read(src))
    f.puts "<div id='toc'>"
    f.write markdown.toc_content
    f.puts "</div>"
    f.write markdown.to_html
    f.write File.read("./template/footer.html")
  end
end

def build_index
  File.open("./pages/index.md","w+") do |index_file|
    index_file.puts("wiki index\n=")
    `cd html;find .`.split("\n").each do |f|
      next if File.directory?("html/"+f)
      next if f =~ /DS_Store/
      index_file.puts "- [#{f.sub(/^html\//,'')}](#{f})"
    end
  end
end

dw = DirectoryWatcher.new '.', :pre_load => true, :scanner => :em
dw.glob = 'pages/**/*'
dw.interval = 2.0
dw.stable = 2
dw.persist = "pages_state.yml"
dw.add_observer do |*args|
  args.each do |event|
    puts event
    fpath=event.path
    src=File.expand_path(fpath)
    dest = File.expand_path(fpath.sub(/^\.\/pages/,'html').sub(/\..*$/,'')+'.html')
    case event.type
    when :modified
      process_file(src,dest)
    when :added
      process_file(src,dest)
      next if fpath === "./pages/index.md"
      build_index
    when :removed
      puts "deleting #{dest}"
      File.delete(dest)
      build_index
    end
    puts ' '
  end
end

loop do
  dw.load!
  dw.run_once
  dw.persist!
  sleep dw.interval
end