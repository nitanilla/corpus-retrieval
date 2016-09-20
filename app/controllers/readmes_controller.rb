class ReadmesController < ApplicationController

  def index
    @sets = ReadmesSet.all.to_a.sort_by(&:created_at).reverse
  end

  def download
    set = ReadmesSet.find(params[:readme_id])
    send_data set.zip_to_download, filename: set.filename, type: 'application/octet-stream'
  end

  def search_form; end

  def search
    readmes_set = ReadmesSet.create! query: params[:q]
    ReadmesSetCreatorWorker.perform_async readmes_set.id
    redirect_to readmes_path
  end
end
