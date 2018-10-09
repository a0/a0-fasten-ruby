RSpec.describe Fasten do
  it 'can load a YAML file' do
    Fasten.load('spec/yaml_spec.yml')
  end

  it 'can perform a YAML file' do
    f = Fasten.load('spec/yaml_spec.yml')
    f.perform
  end
end
