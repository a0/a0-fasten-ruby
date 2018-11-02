RSpec.describe Fasten do
  it 'can run map' do |ex|
    items = (1..1000).to_a

    result = Fasten.map items, name: ex.description, developer: false do |item|
      item * item
    end

    expected_result = items.map do |item|
      item * item
    end

    expect(result).to eq(expected_result)
  end
end
