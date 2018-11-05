RSpec.shared_examples 'error handling' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  max = OS.windows? ? 10 : 100

  it "using #{process_model}, early stop in case of failure" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    f = Fasten::Runner.new name: ex.description, workers: 1, worker_class: ErrorWorker, developer: false, use_threads: use_threads

    max.times do |index|
      shell = OS.windows? ? "ruby -e 'sleep 0.05; require \"fileutils\"; FileUtils.touch \"#{index}.testfile\"'" : "sleep 0.05; touch #{index}.testfile"
      f.add Fasten::Task.new name: index.to_s, shell: shell
    end
    expect { f.perform }.to raise_error(StandardError)

    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(9)
  end

  it "using #{process_model}, it should wait other tasks end in case of failure" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    f = Fasten::Runner.new name: ex.description, workers: 10, worker_class: ErrorWorker, developer: false, use_threads: use_threads

    max.times do |index|
      shell = OS.windows? ? "ruby -e 'sleep 0.3; require \"fileutils\"; FileUtils.touch \"#{index}.testfile\"'" : "sleep 0.3; touch #{index}.testfile"
      f.add Fasten::Task.new name: index.to_s, shell: shell
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
