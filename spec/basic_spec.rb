# frozen_string_literal: true

RSpec.describe Fasten do
  it 'performs an empty runner' do |ex|
    runner = Fasten.runner name: ex.description
    runner.start

    expect(runner.task_list).to be_empty
  end

  it 'performs 1 task' do |ex|
    runner = Fasten.runner name: ex.description

    sample = rand(100)
    mytask = runner.task 'test' do
      puts "HERE WE ARE #{ex.description}"
      sample
    end

    runner.start

    expect(mytask.state).to eq(:DONE)
    expect(mytask.result).to eq(sample)
  end

  count = 10
  it "performs #{count} tasks sequentially" do |ex|
    runner = Fasten.runner name: ex.description

    sample = rand(count)
    1.upto(count) do |index|
      runner.task "sequence #{index}" do
        sleep(rand / 10)

        sample + index
      end
    end

    runner.start

    expect(runner.task_list.map(&:state).tally).to eq({ DONE: count })
    expect(runner.task_list.map(&:result).sum).to eq((count * sample) + 1.upto(count).sum)
  end

  count = 1000
  it "performs #{count} tasks sequentially" do |ex|
    runner = Fasten.runner name: ex.description

    sample = rand(count)
    1.upto(count) do |index|
      runner.task "sequence #{index}" do
        sleep(rand / 10)

        sample + index
      end
    end

    runner.start

    expect(runner.task_list.map(&:state).tally).to eq({ DONE: count })
    expect(runner.task_list.map(&:result).sum).to eq((count * sample) + 1.upto(count).sum)
  end

  count = 100
  it "performs #{count} parent tasks with 2 nested dependencies" do |ex|
    runner = Fasten.runner name: ex.description

    sample = rand(count)
    sample_block = proc do |task|
      sleep(rand / 10)

      OpenStruct.new time: Time.now, sum: sample + task.name.split.last.to_i, after: Array(task.after), dependants: task.dependants # rubocop:disable Style/OpenStructUse
    end
    1.upto(count) do |index|
      runner.task "parent #{index}", &sample_block
      runner.task "child #{index}", after: "parent #{index}", &sample_block
      runner.task "grandchild #{index}", after: "child #{index}", &sample_block
    end

    runner.start

    expect(runner.task_list.map(&:state).tally).to eq({ DONE: 3 * count })

    runner.task_list.each do |task|
      task.result.after.each do |after|
        after_task = runner[after]
        expect(task.result.time).to be > after_task.result.time
      end
    end

    sum = runner.task_list.map(&:result).map(&:sum).sum
    expect(sum).to eq(3 * ((count * sample) + 1.upto(count).sum))
  end
end
