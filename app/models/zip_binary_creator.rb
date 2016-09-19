module ZipBinaryCreator
  extend self

  def create_zip_for(files)
    stringio = Zip::OutputStream.write_buffer do |zio|
      files.each do |file|
        filename = file[:filename]
        content = file[:content]
        zio.put_next_entry filename
        zio.write content
      end
    end
    stringio.rewind
    stringio.sysread
  end
end
