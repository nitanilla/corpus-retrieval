require "sinatra"
require "./github_consumer"

get "/readmes" do
  readmes = GithubConsumer.get_readmes params[:q]
  binary = ZipBinaryCreator.create_zip_for(readmes)
  content_type 'application/octet-stream'
  attachment(params[:q].gsub(/ +/, "_") + ".zip")
  response.headers["Set-Cookie"] = "fileUploading=true"
  binary
end


get "/:filename.js" do
  content_type "text/javascript"
  File.read params["filename"] + ".js"
end

get "/:filename.gif" do
  content_type "text/javascript"
  File.read params["filename"] + ".gif"
end

get "/" do
  content_type "text/html"
  File.read "index.html"
end
