RSpec.shared_examples 'ui' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, shows progressbar correctly" do |ex|
    f = Fasten::Runner.new name: ex.description, workers: 1, use_threads: use_threads

    500.times do |index|
      f.add Fasten::Task.new name: "t-#{index}", shell: 'sleep 0.01'
    end

    f.perform
  end
end

RSpec.describe Fasten do
  it_behaves_like 'ui', false if OS.posix?
  it_behaves_like 'ui', true
end
