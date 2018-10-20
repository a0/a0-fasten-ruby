RSpec.describe Fasten do
  it 'can load a YAML file' do |ex|
    Fasten.load('spec/yaml_spec.yml', name: ex.description)
  end

  it 'can perform a YAML file' do |ex|
    `rm -f *.testfile`
    f = Fasten.load('spec/yaml_spec.yml', name: ex.description)
    f.perform
    f.stats_table

    files = Dir['*.testfile']
    items = f.task_list.map { |item| "#{item}.testfile" }
    `rm -f *.testfile`

    raise "Files don't match, files: #{files} items: #{items}" unless files.sort == items.sort
  end
end
