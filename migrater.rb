module Migrater
  class Migration
    attr_reader :name, :options

    delegate :increment_counter, to: :reporter

    def initialize(name, options = {})
      @name = name
      @options = options
      ActiveRecord::Base.logger.level = Logger::WARN # suppress SQL logging
    end

    def perform
      user_name?
      reporter.start
      yield
      reporter.finish
    rescue StandardError => exception
      handle exception
      raise
    end

    def process_item(&block)
      item.process &block
    end

    def item
      @item ||= Item.new(self)
    end

    def files
      @files ||= Files.new(self)
    end

    def user_name
      @user_name ||= options[:user_name] || ENV["USER"]
    end

    def report_directory
      @report_directory ||= begin
        directory = File.join(report_root, options[:report_directory] || default_report_directory)
        FileUtils.mkdir_p directory
        console "Results for #{name} are in #{directory}"
        directory
      end
    end

    def log(text, severity = Logger::INFO)
      logger.add severity, text
    end

    def console(text)
      puts text # rubocop:disable Rails/Output
    end

    def tee(text, severity = Logger::INFO)
      log text, severity
      console text
    end

    def really_migrate?
      @really_migrate ||= ENV["MIGRATE_DATA"] == "true"
    end

    def handle(exception)
      logger.error "#{exception.class}\n#{exception.message}\n  from #{exception.backtrace.join("\n  from ")}"
    end

    private

    def reporter
      @reporter ||= Reporter.new(self)
    end

    def progress
      @progress ||= Progress.new(self)
    end

    def logger
      @logger ||= begin
        new_logger = Logger.new(File.join(report_directory, "report.log"))
        new_logger.formatter = Logger::Formatter.new
        new_logger.level = log_level
        new_logger
      end
    end

    def log_level
      options[:log_level] || ENV.fetch("LOG_LEVEL", Logger::INFO)
    end

    def default_report_directory
      "#{Time.zone.now.strftime('%F_%H-%M-%S')}_#{name.demodulize.underscore}"
    end

    def report_root
      Rails.configuration.live_environment ? files_root.join("tmp", user_folder, "openc", "migrations") : files_root
    end

    def user_folder
      user_name.parameterize
    end

    def files_root
      Rails.configuration.files_root
    end

    def user_name?
      return true if user_name.present?

      raise <<-MESSAGE.strip_heredoc
        You need to set user_name to whoever is performing the migration. This
        can be done by setting an environment variable USER to the correct
        value or at any point by calling `migration.user_name = "Joe Bloggs"`
      MESSAGE
    end
  end

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

  # Report on a data migration
  class Reporter
    attr_reader :migration, :state

    def initialize(migration)
      @migration = migration
    end

    def start
      reset_migration
      migration.tee "#{name} beginning at #{start_time}"
      readme_file.puts readme
      readme_file.flush
      start_time
    end

    def finish
      files.close
      progress.finish
      migration.tee "#{name} finished at #{finish_time}"
      migration.tee "#{progress.nicenumber(counter)} #{name} records processed in #{progress.nicefloat(elapsed_time)} seconds"
      migration.console "Results for #{name} are in #{migration.report_directory}"
      nil # tidy console output
    end

    def increment_counter
      state.counter += 1
      progress.show
      counter
    end

    def output_file(file_name)
      files.open file_name
    end

    private

    delegate :progress, :files, :name, to: :migration
    delegate :start_time, :finish_time, :elapsed_time, :counter, to: :state

    def readme
      text = <<-TEXT.strip_heredoc
        # OpenCorporates data migration

        ## #{name}

        * Run as: `#{migration.user_name}`
        * Git commit: `#{git_commit}`
        * Report directory: `#{migration.report_directory}`

        ## Environment variables

        | Variable | Value |
        | - | - |
      TEXT

      text + environment_variables_markdown_table
    end

    def git_commit
      commit_hash = `git log -1 --format="%H" 2>&1`.split("\n").first.strip
      commit_hash = "not a git repository" if commit_hash =~ /Not a git repository/
      commit_hash
    end

    def environment_variables_markdown_table
      ENV.sort.to_h.map { |k, v| "| #{k} | #{v} |" }.join("\n")
    end

    def readme_file
      @readme_file ||= files["README_#{name.gsub("::", "_")}.md"]
    end

    def reset_migration
      @state = progress.reset
    end
  end

  # Console output to show progress (if configured to do so)
  class Progress
    include ActionView::Helpers::NumberHelper

    attr_reader :state, :expected, :progress_each

    def initialize(migration)
      @migration = migration
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

      migration.tee "Processing #{nicenumber(expected)} #{name} items"
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

    attr_reader :migration

    delegate :options, :name, :console, to: :migration
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

  # Manage reporting, logging and other output files
  class Files
    def initialize(migration)
      @migration = migration
    end

    def open(file_name)
      return open_files[file_name] if open_files.key?(file_name)
      path = Pathname.new File.join(report_directory, file_name)
      FileUtils.mkdir_p path.parent
      file = File.new(path, "w")
      open_files[file_name] = file
      file
    end

    alias [] open

    def close
      open_files.delete_if do |_, open_file|
        open_file.close
        true
      end
    end

    private

    def report_directory
      @report_directory ||= @migration.report_directory
    end

    def open_files
      @open_files ||= {}
    end
  end
end
