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

      @opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options] FILE/DIRECTORY"
        opts.separator ''
        opts.separator 'Options'

        opts.on '-n', '--name NAME', String, "Name of this job" do |name|
          @options[:name] = name
        end
        opts.on '-w', '--workers WORKERS', Numeric, "Number of processes/threads to use (#{Parallel.physical_processor_count} on this machine)" do |workers|
          @options[:workers] = workers
        end
        opts.on '-t', '--threads' do
          @options[:use_threads] = true
        end
        opts.on '-p', '--processes' do
          @options[:use_threads] = false
        end
        opts.on '-v', '--version' do
          puts Fasten::VERSION
          exit 0
        end
        opts.on_tail '-h', '--help' do
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

      show_help if ARGV.length.zero?

      runner(@options)
      load_fasten ARGV

      runner.perform
    end
  end
end
