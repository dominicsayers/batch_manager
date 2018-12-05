module BatchManager
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
        # Data migration

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
end
