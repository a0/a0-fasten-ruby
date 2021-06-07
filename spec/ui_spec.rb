RSpec.shared_examples 'ui' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  max = OS.windows? ? 100 : 500

  it "using #{process_model}, shows progressbar correctly for #{max} tasks" do |ex|
    runner = Fasten::Runner.new name: ex.description, jobs: 1, use_threads: use_threads

    max.times do |index|
      shell = OS.windows? ? "ruby -e 'sleep 0.1'" : 'sleep 0.01'
      runner.task "t-#{index}", shell: shell
    end

    runner.perform
  end
end

RSpec.describe Fasten do
  it_behaves_like 'ui', false if OS.posix? && !ENV['FASTEN_RSPEC_NO_PROCESSES']
  it_behaves_like 'ui', true  unless ENV['FASTEN_RSPEC_NO_THREADS']
end
