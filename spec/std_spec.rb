RSpec.shared_examples 'stdout, stderr' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, shell writes stdout to file" do |ex|
    FileUtils.rm_rf Dir.glob('fasten/log/task/std-a-*')

    runner = Fasten::Runner.new name: ex.description, jobs: 5, use_threads: use_threads
    Array.new(25) { |index| "std-a-#{index}" }.each do |name|
      runner.task name, shell: "echo SHELL STDOUT ES #{name}"
    end

    runner.perform

    Array.new(25) { |index| "std-a-#{index}" }.each do |name|
      text = File.open("fasten/log/task/#{name}.log").grep(/SHELL STDOUT ES/).first.to_s.chomp
      expect(text).to eq("SHELL STDOUT ES #{name}")
    end
  end

  it "using #{process_model}, shell writes stdout to file" do |ex|
    FileUtils.rm_rf Dir.glob('fasten/log/task/std-b-*')

    runner = Fasten::Runner.new name: ex.description, jobs: 5, use_threads: use_threads
    Array.new(25) { |index| "std-b-#{index}" }.each do |name|
      runner.task name, shell: "echo SHELL STDERR ES #{name}>&2"
    end

    runner.perform

    Array.new(25) { |index| "std-b-#{index}" }.each do |name|
      text = File.open("fasten/log/task/#{name}.log").grep(/SHELL STDERR ES/).first.to_s.chomp
      expect(text).to eq("SHELL STDERR ES #{name}")
    end
  end

  it "using #{process_model}, ruby writes stdout to file" do |ex|
    FileUtils.rm_rf Dir.glob('fasten/log/task/std-c-*')

    runner = Fasten::Runner.new name: ex.description, jobs: 5, use_threads: use_threads
    Array.new(25) { |index| "std-c-#{index}" }.each do |name|
      runner.task name, ruby: "STDOUT.puts 'RUBY STDOUT ES #{name}.constant'; $stdout.puts 'RUBY stdout ES #{name}.object'"
    end

    runner.perform

    Array.new(25) { |index| "std-c-#{index}" }.each do |name|
      text = File.open("fasten/log/task/#{name}.log").grep(/RUBY STDOUT ES/).first.to_s.chomp
      expect(text).to eq("RUBY STDOUT ES #{name}.constant")
      text = File.open("fasten/log/task/#{name}.log").grep(/RUBY stdout ES/).first.to_s.chomp
      expect(text).to eq("RUBY stdout ES #{name}.object")
    end
  end

  it "using #{process_model}, ruby writes stderr to file" do |ex|
    FileUtils.rm_rf Dir.glob('fasten/log/task/std-d-*')

    runner = Fasten::Runner.new name: ex.description, jobs: 5, use_threads: use_threads
    Array.new(25) { |index| "std-d-#{index}" }.each do |name|
      runner.task name, ruby: "STDERR.puts 'RUBY STDERR ES #{name}.constant'; $stderr.puts 'RUBY stderr ES #{name}.object'"
    end

    runner.perform

    Array.new(25) { |index| "std-d-#{index}" }.each do |name|
      text = File.open("fasten/log/task/#{name}.log").grep(/RUBY STDERR ES/).first.to_s.chomp
      expect(text).to eq("RUBY STDERR ES #{name}.constant")
      text = File.open("fasten/log/task/#{name}.log").grep(/RUBY stderr ES/).first.to_s.chomp
      expect(text).to eq("RUBY stderr ES #{name}.object")
    end
  end
end

RSpec.describe Fasten do
  it_behaves_like 'stdout, stderr', false if OS.posix? && !ENV['FASTEN_RSPEC_NO_PROCESSES']
  it_behaves_like 'stdout, stderr', true  unless ENV['FASTEN_RSPEC_NO_THREADS']
end
