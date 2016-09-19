class ReadmesSetCreatorWorker
  include Sidekiq::Worker
  sidekiq_options retry: false

  def perform(query)
    filename = query.gsub(/ +/, "_") + ".zip"
    readmes_set = ReadmesSet.create query: query, filename: filename, worker_id: self.jid
    ReadmesSet.destroy_olds!

    begin
      readmes = GithubConsumer.get_readmes query
      binary = ZipBinaryCreator.create_zip_for(readmes)

      readmes_set.finish! BSON::Binary.new(binary)
    rescue Exception => e
      readmes_set.update_attributes! status: ReadmesSet.status_of(:failed)
      raise e
    end
  end
end
