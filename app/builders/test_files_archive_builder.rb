# The zip archive of the files of one test execution, each written byte for
# byte as the journal kept it: the Commission validates them one by one, and the
# indentation the event page adds on screen is not part of what circulated.
class TestFilesArchiveBuilder
  def initialize(files)
    @files = files
  end

  def build
    archive = Zip::OutputStream.write_buffer(StringIO.new(+'', 'wb')) do |zip|
      @files.each do |file|
        zip.put_next_entry(file.name)
        zip.write(file.content.b)
      end
    end

    archive.string
  end
end
