# frozen_string_literal: true

module Fasten
  module Support
    module State
      attr_accessor :ini, :fin, :dif

      STATE_MEANING = {
        DEPS: 'There are other task need to complete before running this task.',
        PEND: 'The task is ready to run.',
        EXEC: 'The task is running.',
        DONE: 'The task run succesfully.',
        FAIL: 'The task failed to run.'
      }.freeze
      VALID_STATES = STATE_MEANING.keys

      VALID_STATES.each do |state|
        down_state = state.to_s.downcase
        define_method "state_#{down_state}!" do
          @state = state
        end

        define_method "#{down_state}?" do
          @state == state
        end
      end

      def state = @state ||= '????'

      def state=(value)
        raise "Invalid state: #{value}" unless value.in? VALID_STATES

        @state = value
      end
    end
  end
end
