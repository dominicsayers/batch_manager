module BatchManager
  class Item
    def initialize(job)
      @job = job
    end

    def process
      yield
      @job.increment_counter
    rescue StandardError => exception
      @job.handle exception
      raise
    end
  end
end
