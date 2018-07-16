class ResultsController < ApplicationController

  def index
    @results = ResultsZip.all.to_a.sort_by(&:created_at).reverse
  end

  def download
    results = ResultsZip.find(params[:result_id])
    send_data results.zip_to_download, filename: results.filename, type: 'application/octet-stream'
  end

  def search_form; end

  def search
    type = params[:type]
    if ResultsZip::TYPES.include? type
      results = ResultsZip.create! query: params[:q], type: type
      ResultsZipCreatorWorker.perform_async results.id, type
      redirect_to results_path
    else
      redirect_to results_path(q: params[:q]), flash: {error: "Error: You have to choose one of the following types: #{ResultsZip::TYPES.join(", ")}"}
    end
  end
end
