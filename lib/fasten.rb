# frozen_string_literal: true

require 'optparse'
require 'fasten/task'
require 'fasten/runner'
require 'fasten/worker'
require 'fasten/version'

module Fasten
  class << self
    def runner_from_yaml(path, **options)
      runner = Fasten::Runner.new(**options)
      runner.load_yaml(path)

      runner
    end

    def map(list, **options, &block)
      runner(**options).map(list, &block)
    end

    def runner(**options)
      @runner ||= Fasten::Runner.new(**options)
    end

    def cleanup
      @runner = nil
    end

    def reconfigure(**options)
      runner.reconfigure(**options)
    end

    def register(**options, &block)
      runner(**options).register(&block)
    end

    def default_name
      File.basename(Dir.getwd)
    end

    def default_workers
      Parallel.physical_processor_count
    end

    def default_developer
      STDIN.tty? && STDOUT.tty?
    end

    def default_ui_mode
      return @default_ui_mode if defined? @default_ui_mode

      require 'fasten/ui/curses'

      @default_ui_mode = :curses
    rescue StandardError, LoadError
      @default_ui_mode = :console
    end

    def load_fasten(args)
      args.each do |path|
        if File.directory? path
          items = Dir["#{path}/*_fasten.rb"]
          items.each do |item|
            puts "Fasten: loading #{item}"
            load item
          end
        elsif File.file? path
          puts "Fasten: loading #{path}"
          load path
        else
          STDERR.puts "Fasten: file/folder not found: #{path}"
          exit 1
        end
      end
    end

    def opt_parser # rubocop:disable Metrics/MethodLength
      return @opt_parser if defined? @opt_parser

      @options = { developer: false }
      @load_path = []

      @opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
        opts.separator ''
        opts.separator 'Examples:'
        opts.separator '    fasten              # load and run all task from fasten/*_fasten.rb'
        opts.separator '    fasten -f tasks.rb  # load task from ruby script'
        opts.separator '    fasten -y tasks.yml # load task from yaml file'
        opts.separator ''
        opts.separator 'Options:'

        opts.on '-n NAME', '--name=NAME', String, "Change name of this runner (default: #{default_name} from current directory)" do |name|
          @options[:name] = name
        end
        opts.on '-f PATH', '--file=PATH', String, 'File or folder with ruby code' do |path|
          @load_path << path
        end
        opts.on '-w WORKERS', '--workers=WORKERS', Numeric, "Number of processes/threads to use (default: #{default_workers} on this machine)" do |workers|
          @options[:workers] = workers
        end
        opts.on '-s', '--[no-]summary', TrueClass, 'Display summary at the end of execution' do |boolean|
          puts "SUMMAMRY: #{boolean}"
          @options[:summary] = boolean
        end
        opts.on '--ui=UI', String, "Type of UI: curses, console. (default: #{default_ui_mode} on this machine)" do |ui_mode|
          @options[:ui_mode] = ui_mode
        end
        opts.on '-t', '--threads', 'Use threads workers for parallel execution' do
          @options[:use_threads] = true
        end
        opts.on '-p', '--processes', 'Use process workers for parallel execution' do
          @options[:use_threads] = false
        end
        opts.on '-v', '--version', 'Display version info' do
          puts Fasten::VERSION
          exit 0
        end
        opts.on_tail '-h', '--help', 'Shows this help' do
          puts opts
          exit 0
        end
      end
    end

    def show_help
      puts opt_parser
      exit 1
    end

    def invoke
      opt_parser.parse!

      runner @options
      load_fasten @load_path

      show_help if runner.task_list.empty?

      runner.perform
    end
  end
end
