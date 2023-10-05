# frozen_string_literal: true

RSpec.describe Fasten do
  it 'performs an empty runner' do |ex|
    runner = Fasten.runner name: ex.description
    runner.start
  end

  it 'performs one task' do |ex|
    runner = Fasten.runner name: ex.description
    sample = rand(100)
    mytask = runner.task 'test' do
      puts "HERE WE ARE #{ex}"
      sample
    end
    runner.start

    expect(mytask.result).to eq(sample)
  end
end
