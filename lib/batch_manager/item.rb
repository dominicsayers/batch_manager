module BatchManager
  class Item
    def initialize(migration)
      @migration = migration
    end

    def process
      yield
      @migration.increment_counter
    rescue StandardError => exception
      @migration.handle exception
      raise
    end
  end
end
