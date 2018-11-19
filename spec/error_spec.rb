RSpec.shared_examples 'error handling' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'
  wait = OS.windows? ? 0.5 : 0.2

  it "using #{process_model}, early stop in case of failure" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    runner = Fasten::Runner.new name: ex.description, workers: 1, worker_class: ErrorWorker, developer: false, use_threads: use_threads

    100.times do |index|
      shell = OS.windows? ? "ruby -e 'sleep #{wait}; require \"fileutils\"; FileUtils.touch \"#{index}.testfile\"'" : "sleep #{wait}; touch #{index}.testfile"
      runner.task index.to_s, shell: shell
    end
    expect { runner.perform }.to raise_error(StandardError)

    sleep 2 * wait
    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(9)
  end

  it "using #{process_model}, it should wait other tasks end in case of failure" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    runner = Fasten::Runner.new name: ex.description, workers: 10, worker_class: ErrorWorker, developer: false, use_threads: use_threads

    100.times do |index|
      shell = OS.windows? ? "ruby -e 'sleep #{wait}; require \"fileutils\"; FileUtils.touch \"#{index}.testfile\"'" : "sleep #{wait}; touch #{index}.testfile"
      runner.task index.to_s, shell: shell
    end
    expect { runner.perform }.to raise_error(StandardError)

    sleep 2 * wait
    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(90)
  end
end

RSpec.describe Fasten do
  it_behaves_like 'error handling', false if OS.posix?
  it_behaves_like 'error handling', true
end
