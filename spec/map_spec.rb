RSpec.shared_examples 'map functionality' do |use_threads|
  process_model = use_threads ? 'threads' : 'processes'

  it "using #{process_model}, Fasten.map works as expected" do |ex|
    items = (1..1000).to_a

    result = Fasten.map items, name: ex.description, developer: false, use_threads: use_threads do |item|
      item * item
    end

    expected_result = items.map do |item|
      item * item
    end

    expect(result).to eq(expected_result)
  end

  it "using #{process_model}, fasten_instance.map works as expected" do |ex|
    items = (1..1000).to_a

    f = Fasten::Runner.new name: ex.description, developer: false, use_threads: use_threads

    result = f.map items do |item|
      item * item
    end

    expected_result = items.map do |item|
      item * item
    end

    expect(result).to eq(expected_result)
  end
end

RSpec.describe Fasten do
  it_behaves_like 'map functionality', false if OS.posix?
  it_behaves_like 'map functionality', true
end
