Fasten.register do
  task 'deploy', after: %w[compile-1 compile-2 compile-3] do
    puts "#{$PID} running deploy…"
    sleep 0.5
    FileUtils.touch 'deploy.testfile'
    puts "#{$PID} ok deploy."
  end

  task 'notify', after: 'deploy' do
    puts "#{$PID} running notify…"
    sleep 0.5
    FileUtils.touch 'notify.testfile'
    puts "#{$PID} ok notify."
  end
end
