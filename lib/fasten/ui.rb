require 'fasten/ui/console'
require 'fasten/ui/curses'

module Fasten
  module UI
    def ui
      @ui ||= STDIN.tty? && STDOUT.tty? ? Fasten::UI::Curses.new(executor: self) : Fasten::UI::Console.new(executor: self)
    end

    def run_ui
      ui.update

      yield
    ensure
      ui.cleanup
    end
  end
end
