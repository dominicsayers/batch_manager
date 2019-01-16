module BatchManager
  # Holds all the job reporter's state during the job
  # we can simply reset this if we need to restart
  class State
    attr_accessor :counter, :previous_counter, :items_in_period, :elapsed_time, :previous_time, :delim, :stats

    def initialize
      @counter = 0
      @previous_counter = 0
      @elapsed_time = 0
      @items_in_period = 0
      @previous_time = current_time
      @delim = ''
      @stats = {}
    end

    def start_time
      @start_time ||= current_time
    end

    def finish_time
      @finish_time ||= current_time
    end

    def elapsed_time
      @elapsed_time ||= finish_time - start_time
    end

    def current_time
      self.class.current_time
    end

    def self.current_time
      Time.current # zone.at Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
