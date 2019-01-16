module BatchManager
  # Console output to show progress (if configured to do so)
  class Progress
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::DateHelper

    attr_reader :state, :expected, :progress_every

    def initialize(job)
      @job = job
      self.expected = nil
      self.progress_every = nil
      reset
    end

    def show?
      @show ||= options[:show_progress] || false
    end

    def start
      @show = true
    end

    def finish; end

    def show
      return unless show?
      return unless compute_position

      average_items_in_period = counter / stats[:frequency]

      console "#{identifier}\t#{nice_number(counter)} items processed " \
            "(" \
            "rate: #{nice_number(items_in_period)} items in #{nice_elapsed_time(elapsed_time)}, " \
            "average: #{nice_number(average_items_in_period)} items, " \
            "max: #{nice_number(stats[:max_items_in_period])} items" \
            "#{eta})"
    end

    def reset
      @state = State.new
    end

    def expected=(value)
      @expected = value || options[:expected]
      job.tee "Processing #{nice_number(expected)} #{name} items"
    end

    def progress_every=(value)
      @progress_every = value || options[:progress_every] || 60
    end

    def nice_number(number)
      number_with_delimiter(number.to_i, delimiter: ',')
    end

    def nice_float(number)
      number < 5 ? number.round(2) : nice_number(number)
    end

    def nice_elapsed_time(number)
      current_time = State.current_time
      distance_of_time_in_words(current_time, current_time + number, include_seconds: true)
    end

    private

    attr_reader :job

    delegate :options, :name, :console, to: :job
    delegate :counter, :previous_counter, :items_in_period, :elapsed_time, :previous_time, :stats, to: :state

    def compute_position
      current_time = State.current_time
      elapsed_time = current_time - previous_time

      return if elapsed_time < progress_every

      state.previous_time = current_time
      state.elapsed_time = elapsed_time

      state.items_in_period = counter - previous_counter
      state.previous_counter = counter

      stats[:max_items_in_period] = items_in_period if items_in_period > (stats[:max_items_in_period] || 0)
      stats[:frequency] = (stats[:frequency] || 0) + 1

      true
    end

    def eta
      return unless expected && !expected.zero?
      percent_complete = 100.0 * counter / expected
      seconds_to_go = (expected - counter) * progress_every / items_in_period
      ", #{nice_float(percent_complete)}% complete, ETA #{State.current_time + seconds_to_go}"
    end

    def identifier
      @identifier ||= begin
        worker_number = defined?(Parallel) && Parallel.worker_number ? "Worker #{sprintf('%3d', Parallel.worker_number)}" : nil
        [worker_number, name].compact.join(": ")
      end
    end
  end
end
