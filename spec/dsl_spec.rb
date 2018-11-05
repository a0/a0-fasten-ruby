RSpec.describe Fasten do
  it 'simple dsl' do |ex|
    class MyWorker < Fasten::Worker
      def do_sum(*args)
        puts "do_sum: #{args}"
        args.sum
      end
    end

    Fasten.register name: ex.description, worker_class: MyWorker, use_threads: false do
      task 'probando' do
        result = do_sum 5, 6
        puts "probando: #{result}!"
        result
      end

      task 'terminando', after: 'probando' do
        result = do_sum 7, 8
        puts "terminando: #{result}."
        result
      end

      perform
      stats_table
    end
  end
end
