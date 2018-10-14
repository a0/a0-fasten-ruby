RSpec.describe Fasten do
  it 'shows progressbar correctly' do |ex|
    f = Fasten::Executor.new name: ex.description, workers: 1

    500.times do |index|
      f.add Fasten::Task.new name: "t-#{index}", shell: 'sleep 0.01'
    end

    f.perform
  end
end
