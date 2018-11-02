RSpec.describe Fasten do
  it 'can load a YAML file' do |ex|
    Fasten.runner_from_yaml('spec/yaml_spec.yml', name: ex.description)
  end

  it 'can perform a YAML file' do |ex|
    FileUtils.rm_rf Dir.glob('*.testfile')
    f = Fasten.runner_from_yaml('spec/yaml_spec.yml', name: ex.description)
    f.perform
    f.stats_table

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    FileUtils.rm_rf Dir.glob('*.testfile')

    expect(files.sort).to eq(items.sort)
  end
end
