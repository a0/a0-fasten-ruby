require 'fasten/ui/console'

module Fasten
  module Support
    module UI
      def ui
        require 'fasten/ui/curses'
        @ui ||= STDIN.tty? && STDOUT.tty? ? Fasten::UI::Curses.new(runner: self) : Fasten::UI::Console.new(runner: self)
      rescue StandardError, LoadError
        @ui = Fasten::UI::Console.new(runner: self)
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
