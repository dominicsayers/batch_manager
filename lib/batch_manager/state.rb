module BatchManager
  # Holds all the migration reporter's state during the migration
  # we can simply reset this if we need to restart
  class State
    attr_accessor :counter, :previous_position, :previous_time, :delim

    def initialize
      @counter = 0
      @previous_position = 0
      @previous_time = Time.current
      @delim = ""
    end

    def start_time
      @start_time ||= Time.current
    end

    def finish_time
      @finish_time ||= Time.current
    end

    def elapsed_time
      @elapsed_time ||= finish_time - start_time
    end
  end
end
