RSpec.shared_examples 'error handling' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, early stop in case of failure" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    f = Fasten::Runner.new name: ex.description, workers: 1, worker_class: ErrorWorker, developer: false, use_threads: use_threads

    100.times do |index|
      f.add Fasten::Task.new name: index.to_s, shell: "sleep 0.05; touch #{index}.testfile"
    end
    expect { f.perform }.to raise_error(StandardError)

    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(9)
  end

  it "using #{process_model}, it should wait other tasks end in case of failure" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    f = Fasten::Runner.new name: ex.description, workers: 10, worker_class: ErrorWorker, developer: false, use_threads: use_threads

    100.times do |index|
      f.add Fasten::Task.new name: index.to_s, shell: "sleep 0.1; touch #{index}.testfile"
    end
    expect { f.perform }.to raise_error(StandardError)

    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(90)
  end
end

RSpec.describe Fasten do
  it_behaves_like 'error handling', false if OS.posix?
  it_behaves_like 'error handling', true
end
