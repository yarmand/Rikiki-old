#!/usr/bin/env ruby

require 'directory_watcher'
require 'eventmachine'
require 'redcarpet'
require 'fileutils'


def get_conf_value(file, key)
  File.open(file,"r").each do |l|
    k,v = l.split("=")
    return v if k === key
  end
  raise "Can't find a value for key #{key} in file #{file}"
end

module Rikiki

  class Watcher
    @@watchers = []


    @pid=false
    @instance=false


    #
    # parameters
    #  folder: the folder to watch
    #
    def initialize(p)
      @folder = p[:folder]
      @@watchers << self
    end

    def watch
      dir = file.expand_path(@folder)
      @conf_file = dir + "/.rikiki"
      @pages_dir = File.expand_path(get_conf_value(@conf_file,"pages_dir"))
      @output_dir = File.expand_path(get_conf_value(@conf_file,"output_dir"))
      @index_file = "#{@pages_dir}/index.md"
      dw = DirectoryWatcher.new dir, :pre_load => true, :scanner => :em
      dw.glob = "#{@pages_dir}/**/*"
      dw.interval = 2.0
      dw.stable = 2
      dw.persist = ".rikiki_pages_state.yml"
      dw.add_observer do |*args|
        args.each do |event|
          puts event
          fpath=event.path
          src=File.expand_path(fpath)
          dest = File.expand_path(fpath.sub(/#{@pages_dir}/,@output_dir).sub(/\..*$/,'')+'.html')
          case event.type
          when :modified
            Renderer::process_file(src,dest)
          when :added
            Renderer::process_file(src,dest)
            next if fpath === @index_file
            build_index
          when :removed
            puts "deleting #{dest}"
            File.delete(dest)
            build_index
          end
          puts ' '
        end
      end

      Thread.new do
        loop do
          dw.load!
          dw.run_once
          dw.persist!
          sleep dw.interval
        end
      end
    end 

    def build_index
      File.open(@index_file,"w+") do |index_file|
        index_file.puts("<H1>wiki index</H1>\n")
        `cd #{@output_dir};find .`.split("\n").each do |f|
        next if f =~ /DS_Store/
        pretty_name=f.sub(/^\.\//,'')
        if File.directory?(@output_dir+"/"+f)
          next if pretty_name === "."
          index_file.puts "\n#{pretty_name}\n=\n"
          next
        end
        index_file.puts "- [#{pretty_name}](#{f})"
      end
    end
  end

  class Deamon
    def self.launch
      @conf_folder=File.expand_path('~/.rikiki')
      @folders_file = @conf_folder+"/watched_folders.list"
      @pid_file = @conf_folder+"/.pid"
      @wathcers = []
      unless Dir.exists?(@conf_folder) do
        Dir.mkdir(@conf_folder)
        File.open(@folders_file, "w") {}
      end
      @folders = File.read(@folders_file).split("\n")
      if File.exists?(@pid_file)
        pid=File.read(@pid_file).to_i
        begin
          Process.kill(0, pid)
          raise :ALREADY_RUNNING, "Another instance of twiki already running"
          exit
        rescue Errno::ESRCH
        end
      end
      puts "Creating a new process"
      File.open(@pid_file,"w+") {|f| f.puts $$}

      @folders.each do |d|
        Watcher.new(d).watch
      end

    end

    def self.add_folder(path)
      raise "folder #{path} is already watched by Rikiki" unless @folders.include? path
      File.open(@folders_file,"a") {|f| f.puts path }
      Watcher.new(path).watch
    end

  end

  class Renderer
    def self.process_file(src,dest)
      puts "processing #{src} => #{dest}"
      dir=File.dirname(dest)
      # puts "creating #{dir}"
      FileUtils.mkdir_p(dir)
      File.open(dest,  "w+") do |f|
        f.write File.read("./template/header.html").sub(/<!--BASE-->/,"<base href='#{dest}'/>").sub(/--CSS--/,File.expand_path("template/twiki.css")).sub(/--INDEX--/,File.expand_path("html/index.html"))
        #    f.write GitHub::Markup.render(src)
        md_text = File.read(src)
        md_options = {no_intra_emphasis: true, tables: true, fenced_code_blocks: true, autolink: true, strikethrough: true, lax_html_blocks: true, space_after_headers: true, superscript: true, with_toc_data: true}
        markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML_TOC, md_options)
        f.puts "<div id='toc'>"
        f.write markdown.render(md_text)
        f.puts "</div>"
        markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, md_options)
        f.write markdown.render(md_text)
        f.write File.read("./template/footer.html")
      end
    end
  end

  Deamon::launch

end
end
end

