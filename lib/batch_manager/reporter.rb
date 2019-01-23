module BatchManager
  # Report on a data job
  class Reporter
    attr_reader :job, :state

    def initialize(job)
      @job = job
    end

    def start
      reset_job
      job.tee "#{name} beginning at #{start_time}"
      readme_file.puts readme
      readme_file.flush
      start_time
    end

    def finish
      progress.finish
      announce_finish_time
      announce_finish_rate
      job.console "Results for #{name} are in #{job.report_directory}"
      files.flush
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

    delegate :progress, :files, :name, to: :job
    delegate :start_time, :finish_time, :elapsed_time, :counter, to: :state

    def readme
      text = <<-TEXT.strip_heredoc
        # Data job

        ## #{name}

        * Run as: `#{job.user_name}`
        * Git commit: `#{git_commit}`
        * Report directory: `#{job.report_directory}`

        ## Environment variables

        | Variable | Value |
        | - | - |
      TEXT

      text + environment_variables_markdown_table
    end

    def git_commit
      commit_hash = `git log -1 --format="%H" 2>&1`.split("\n").first.strip
      commit_hash = 'not a git repository' if commit_hash =~ /Not a git repository/
      commit_hash
    end

    def environment_variables_markdown_table
      ENV.sort.to_h.map { |k, v| "| #{k} | #{v} |" }.join("\n")
    end

    def readme_file
      @readme_file ||= files["README_#{name.gsub('::', '_')}.md"]
    end

    def reset_job
      @state = progress.reset
    end

    def announce_finish_time
      job.tee "#{name} finished at #{finish_time}"
    end

    def announce_finish_rate
      job.tee "#{progress.nice_number(counter)} #{name} records processed " \
        "in #{progress.nice_float(elapsed_time)} seconds"
    end
  end
end
