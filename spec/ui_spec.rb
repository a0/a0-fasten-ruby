RSpec.shared_examples 'ui' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  max = OS.windows? ? 100 : 500

  it "using #{process_model}, shows progressbar correctly" do |ex|
    f = Fasten::Runner.new name: ex.description, workers: 1, use_threads: use_threads

    max.times do |index|
      shell = OS.windows? ? "ruby -e 'sleep 0.1'" : "sleep 0.01"
      f.add Fasten::Task.new name: "t-#{index}", shell: shell
    end

    f.perform
  end
end

RSpec.describe Fasten do
  it_behaves_like 'ui', false if OS.posix?
  it_behaves_like 'ui', true
end
