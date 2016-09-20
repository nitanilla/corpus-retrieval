class ReadmesSetCreatorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(readmes_set_id)
    begin
      readmes_set = ReadmesSet.find readmes_set_id
      prepare readmes_set
      process readmes_set
    rescue Exception => e
      on_failing readmes_set
      raise e
    end
  end

  private

  def prepare(readmes_set)
    filename = readmes_set.query.gsub(/ +/, "_") + ".zip"

    readmes_set.update_attributes! filename: filename, worker_id: self.jid, status: ReadmesSet.status_of(:processing)
    ReadmesSet.destroy_olds!
    readmes_set
  end

  def process(readmes_set)
    readmes = GithubConsumer.get_readmes readmes_set.query
    binary = ZipBinaryCreator.create_zip_for(readmes)

    readmes_set.finish! BSON::Binary.new(binary)
  end

  def on_failing(readmes_set)
    readmes_set && readmes_set.update_attributes!(status: ReadmesSet.status_of(:failed))
  end
end
