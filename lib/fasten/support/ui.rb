require 'fasten/ui/console'
require 'fasten/ui/curses'

module Fasten
  module Support
    module UI
      def ui
        @ui ||= STDIN.tty? && STDOUT.tty? ? Fasten::UI::Curses.new(runner: self) : Fasten::UI::Console.new(runner: self)
      end

      def run_ui
        ui.update

        yield
      ensure
        ui.cleanup
      end
    end
  end
end
