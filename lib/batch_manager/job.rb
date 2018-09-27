require_relative 'files'
require_relative 'item'
require_relative 'progress'
require_relative 'reporter'
require_relative 'state'

module BatchManager
  class Job
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
      @user_name ||= options[:user_name] || ENV['USER']
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
      puts text
    end

    def tee(text, severity = Logger::INFO)
      log text, severity
      console text
    end

    def really_do_it?
      @really_do_it ||= ENV['REALLY_DO_IT'] == 'true'
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
        new_logger = Logger.new(File.join(report_directory, 'report.log'))
        new_logger.formatter = Logger::Formatter.new
        new_logger.level = log_level
        new_logger
      end
    end

    def log_level
      options[:log_level] || ENV.fetch('LOG_LEVEL', Logger::INFO)
    end

    def default_report_directory
      "#{Time.zone.now.strftime('%F_%H-%M-%S')}_#{name.demodulize.underscore.gsub(/[[:space:]]+/, '_')}"
    end

    def report_root
      Rails.configuration.live_environment ? files_root.join('tmp', user_folder, 'openc', 'jobs') : files_root
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
        You need to set user_name to whoever is performing the job. This
        can be done by setting an environment variable USER to the correct
        value or at any point by calling `job.user_name = "Joe Bloggs"`
      MESSAGE
    end
  end
end
