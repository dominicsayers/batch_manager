module BatchManager
  # Console output to show progress (if configured to do so)
  class Progress
    include ActionView::Helpers::NumberHelper

    attr_reader :state, :expected, :progress_each

    def initialize(job)
      @job = job
      self.expected = nil
      self.progress_each = nil
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
      position = current_position
      return unless (position % progress_each).zero?
      return if position == previous_position

      current_time = Time.current
      elapsed_time = current_time - previous_time

      console "#{name}\t#{niceposition(position)} " \
            "(elapsed time: #{nicefloat(elapsed_time)} seconds, " \
            "rate: #{niceposition(rate(elapsed_time))}/#{@rate_unit}#{eta(position, elapsed_time)})"

      state.previous_position = position
      state.previous_time = current_time
    end

    def reset
      state = State.new
      console "Starting at #{state.start_time}" if show?
      @state = state
    end

    def expected=(value)
      @expected = value || options[:expected]
      @percent = @expected.present? && !@expected.zero?
      @rate_unit = @percent ? "min" : "second"
      @progress_each = nil

      job.tee "Processing #{nicenumber(expected)} #{name} items"
    end

    def progress_each=(value)
      @progress_each = value || options[:progress_each] || (@percent ? 1 : 1000)
      @progress_each_float = @progress_each.to_f
    end

    def nicenumber(number)
      number_with_delimiter(number.to_i, :delimiter => ",")
    end

    def niceposition(number)
      percent? ? format("%3d%", number) : nicenumber(number)
    end

    def nicefloat(number)
      number < 5 ? number.round(2) : nicenumber(number)
    end

    private

    attr_reader :job

    delegate :options, :name, :console, to: :job
    delegate :counter, :previous_position, :previous_time, to: :state

    def current_position
      percent? ? 100 * counter / expected : counter
    end

    def percent?
      @percent
    end

    def rate(elapsed_time)
      rate_per_second = @progress_each_float / elapsed_time
      (percent? ? rate_per_second * 60 : rate_per_second).to_i
    end

    def eta(position, elapsed_time)
      return unless percent?
      remaining_percent = 100 - position
      remaining_time = elapsed_time * remaining_percent
      eta = Time.current + remaining_time.seconds
      ", ETA #{eta.to_s(:time)}"
    end
  end
end
