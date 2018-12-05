module BatchManager
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
