# frozen_string_literal: true

require 'optparse'
require 'fasten/task'
require 'fasten/task_manager'
require 'fasten/runner'
require 'fasten/worker'
require 'fasten/version'

require 'fasten/defaults'

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
        opts.banner = "Usage: #{$PROGRAM_NAME} [options] [targets]"
        opts.separator ''
        opts.separator 'Examples:'
        opts.separator '    fasten              # load and run all task from fasten/*_fasten.rb'
        opts.separator '    fasten -f tasks.rb  # load task from ruby script'
        opts.separator '    fasten -y tasks.yml # load task from yaml file'
        opts.separator ''
        opts.separator 'Options:'

        opts.on '-n NAME', '--name NAME', String, "Change name of this runner (default: #{default_name} from current directory)" do |name|
          @options[:name] = name
        end
        opts.on '-f PATH', '--file PATH', String, 'File or folder with ruby code' do |path|
          @load_path << path
        end
        opts.on '-j JOBS', '--jobs JOBS', Numeric, "Maximum number of tasks to execute in parallel (default: #{default_jobs} on this machine)" do |jobs|
          @options[:jobs] = jobs
        end
        opts.on '-s', '--[no-]summary', TrueClass, 'Display summary at the end of execution' do |boolean|
          @options[:summary] = boolean
        end
        opts.on '--ui=UI', String, "Type of UI: curses, console. (default: #{default_ui_mode} on this machine)" do |ui_mode|
          @options[:ui_mode] = ui_mode
        end
        opts.on '-t', '--threads', "Use threads based jobs for parallel execution#{default_use_threads && ' (default on this machine)' || nil}" do
          @options[:use_threads] = true
        end
        opts.on '-p', '--processes', "Use process based jobs for parallel execution#{!default_use_threads && ' (default on this machine)' || nil}" do
          @options[:use_threads] = false
        end
        opts.on '-v', '--version', 'Display version info' do
          puts Fasten::VERSION
          exit 0
        end
        opts.on_tail '-h', '--help', 'Shows this help' do
          show_help
        end
      end
    end

    def show_help(exit_code = 0)
      puts opt_parser
      exit exit_code
    end

    def invoke
      opt_parser.parse!

      @options[:targets] = ARGV.to_a

      runner @options
      @load_path = Dir['fasten/*_fasten.rb'] if @load_path.empty?
      load_fasten @load_path

      show_help 1 if runner.tasks.empty?

      runner.perform
    end
  end
end
