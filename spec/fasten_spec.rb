RSpec.describe Fasten do
  it 'has a version number' do
    expect(Fasten::VERSION).not_to be nil
  end

  it 'performs an empty executor' do
    f = Fasten::Executor.new
    f.perform
  end

  it 'performs 500 tasks executor in parallel' do
    f = Fasten::Executor.new workers: 100
    500.times do |index|
      f.add Fasten::Task.new(name: index.to_s, shell: 'sleep 0.5')
    end
    f.perform
  end

  it 'performs 500 tasks with dependencies' do
    l = {}
    500.times do
      m = rand(65..90).chr
      n = rand(97..122).chr
      l[m] ||= {}
      l[m][n] ||= []
      l[m][n] << { task: "task-#{m}-#{n}-#{l[m][n].count + 1}", after: nil }
    end

    l.values.each do |value|
      depend = nil
      value.values.flatten.sort_by { |k| k[:task] }.each do |item|
        item[:after] = depend
        depend = item[:task]
      end
    end

    f = Fasten::Executor.new(workers: 50)
    l.values.map(&:values).flatten.each do |item|
      puts "#{item[:task]}: #{item[:after]}"
      f.add Fasten::Task.new(name: item[:task], after: item[:after], shell: 'sleep 0.5')
    end
    f.perform
  end
end
