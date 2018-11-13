RSpec.shared_examples 'cli' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, runs a _fasten file" do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    `ruby exe/fasten --#{process_model} --name '#{ex.description}' --file spec/sample_fasten.rb`
    files = Dir['*.testfile']

    Fasten.cleanup
    load 'spec/sample_fasten.rb'
    items = Fasten.runner.task_list.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end
end

RSpec.describe Fasten do
  it_behaves_like 'cli', false if OS.posix?
  it_behaves_like 'cli', true
end
