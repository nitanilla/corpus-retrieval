class ReadmesController < ApplicationController
  def search_form; end

  def search
    readmes = GithubConsumer.get_readmes params[:q]
    binary = ZipBinaryCreator.create_zip_for(readmes)
    cookies[:fileUploading] = "true"
    filename = params[:q].gsub(/ +/, "_") + ".zip"
    send_data binary, filename: filename, type: 'application/octet-stream'
  end
end
