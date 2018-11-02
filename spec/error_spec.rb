class ErrorWorker < Fasten::Worker
  def initialize(*)
    super
    @fail_at ||= ENV['FAILT_AT'] || 10
  end

  def perform(task)
    @count = (@count || 0) + 1
    raise "Simulating Error, counter: #{@count}" if (@count % @fail_at).zero?

    super
  end
end

RSpec.describe Fasten do
  it 'early stop in case of failure' do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    f = Fasten::Runner.new name: ex.description, workers: 1, worker_class: ErrorWorker, developer: false

    100.times do |index|
      f.add Fasten::Task.new name: index.to_s, shell: "sleep 0.05; touch #{index}.testfile"
    end
    expect { f.perform }.to raise_error(StandardError)

    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(9)
  end

  it 'it should wait other tasks end in case of failure' do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')

    f = Fasten::Runner.new name: ex.description, workers: 10, worker_class: ErrorWorker, developer: false

    100.times do |index|
      f.add Fasten::Task.new name: index.to_s, shell: "sleep 0.1; touch #{index}.testfile"
    end
    expect { f.perform }.to raise_error(StandardError)

    files = Dir['*.testfile']
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.count).to eq(90)
  end
end
