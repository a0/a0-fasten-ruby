RSpec.describe Fasten do
  it 'can load a YAML file' do |ex|
    f = Fasten.runner_from_yaml('spec/sample.ruby.yml', name: ex.description)
    expect(f.task_list.count).to eq(13)

    f = Fasten.runner_from_yaml('spec/sample.shell.yml', name: ex.description)
    expect(f.task_list.count).to eq(13)
  end

  it 'can perform a YAML file with ruby code' do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    f = Fasten.runner_from_yaml('spec/sample.ruby.yml', name: ex.description)
    f.perform
    f.stats_table

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end

  it 'can perform a YAML file with shell code' do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    f = Fasten.runner_from_yaml('spec/sample.shell.yml', name: ex.description)
    f.perform
    f.stats_table

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end
end
