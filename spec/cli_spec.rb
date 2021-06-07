RSpec.shared_examples 'cli' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, runs the single first_fasten.rb file" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    `bundle exec ruby exe/fasten --#{process_model} --name '#{ex.description}' --file spec/first_fasten.rb`
    files = Dir['*.testfile']

    Fasten.cleanup
    load 'spec/first_fasten.rb'
    items = Fasten.runner.tasks.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end

  it "using #{process_model}, runs all *_fasten.rb files from a folder" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    `bundle exec ruby exe/fasten --#{process_model} --name '#{ex.description}' --file spec`
    files = Dir['*.testfile']

    Fasten.cleanup
    load 'spec/first_fasten.rb'
    load 'spec/second_fasten.rb'
    items = Fasten.runner.tasks.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end
end

RSpec.describe Fasten do
  it_behaves_like 'cli', false if OS.posix? && !ENV['FASTEN_RSPEC_NO_PROCESSES']
  it_behaves_like 'cli', true  unless ENV['FASTEN_RSPEC_NO_THREADS']
end
