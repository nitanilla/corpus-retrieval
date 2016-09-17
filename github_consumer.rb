require "typhoeus"
require "base64"
require "zip"
require "redis"
require "json"

module GithubConsumer
  module GenericClient
    extend self

    def newhydra
      Typhoeus::Hydra.new(max_concurrency: 14)
    end

    def requestjson(url, log=false, &block)
      request = Typhoeus::Request.new url
      request.on_complete do |response|
        if response.success?
          json = JSON.parse(response.body)
          if !json.is_a?(Hash) || json['message'].nil?
            puts "[OK-#{response.cached?}] #{url}"
            block.call(json)
          else
            puts "[ERR] #{url} #{json.inspect}"
          end
        else
          puts "[FAIL-#{response.cached?}] #{url}"
        end
      end
      request
    end
  end

  module RepositoriesSearcher
    extend self
    extend GenericClient

    MAX_PAGES = 10

    PARAMS_COMBINATIONS = [
      {sort: nil, order: nil}, # best match
      {sort: "stars", order: "desc"},
      {sort: "forks", order: "desc"},
      {sort: "stars", order: "asc", reversed: true},
      {sort: "forks", order: "asc", reversed: true}
    ]

    def get_all_repositories_urls(query)
      repos_url = "https://api.github.com/search/repositories?q=#{query.gsub(" ","+")}+in:readme&per_page=100"
      all_head_urls = []
      hydra = newhydra
      items = []
      PARAMS_COMBINATIONS.each_with_index do |params, i|
        url = UrlBuilder.build(repos_url, 1, params[:sort], params[:order])
        req = requestjson url do |first_page_json|
          items = get_remaning_pages(repos_url, first_page_json, params)

          # une as urls
          all_head_urls[i] = head_urls_from(items, params[:reversed])
        end
        hydra.queue req
      end
      hydra.run
      all_head_urls.reduce(:|)
    end
  private

    def head_urls_from(items, is_reversed)
      # pega url de cada repositorio
      head_urls = items.map do |repo_json|
        repo_json["contents_url"].gsub("{+path}", "")
      end

      is_reversed ? head_urls.reverse : head_urls
    end

    def get_remaning_pages(repos_url, first_page_json, params)
      total_items = first_page_json["total_count"]
      total_pages = [total_items / 100, MAX_PAGES].min

      items = []
      items[1] = first_page_json["items"]
      hydra = newhydra
      (2..total_pages).each do |page|
        page_url = UrlBuilder.build(repos_url, page, params[:sort], params[:order])
        request = requestjson page_url do |json|
          items[page] = json["items"]
        end
        hydra.queue request
      end
      hydra.run
      
      items.compact.flatten
    end
  end
end

module GithubConsumer
  extend self
  extend GenericClient

  README_PATTERN = %r{^readme.?([^.]*)$}i

  EXTENSIONS_PRIORITIES = [/\.md$/, /\.rst$/, /\.html$/, /\..*doc$/, /\..*$/, /^[^.]*$/]

  def get_readmes(query)
    all_head_urls = RepositoriesSearcher.get_all_repositories_urls(query)

    # .map cria uma array com o valor do último statement de cada iteração
    unrecognizeds = []
    hydra = newhydra
    readmes_data = []
    all_head_urls.each_with_index do |head_url, i|
      readme_data = nil
      url = UrlBuilder.build(head_url)
      req = requestjson url do |root_json|
        readme_json = root_json.find_all{|file_json| file_json["path"].match(README_PATTERN)}
          .sort_by{|file_json| priority_of(file_json["path"])}.first
        if readme_json
          readmes_data.push(
            extension: readme_json["path"].match(README_PATTERN)[1],
            url: readme_json["git_url"]
          )
        else
          unrecognizeds << head_url
        end
      end
      hydra.queue req
    end
    hydra.run

    readmes_content = []

    # .compact remove os elementos nulos
    hydra = newhydra
    readmes_data.compact.each.with_index do |readme_data, i|
      url = UrlBuilder.build readme_data[:url]
      req = requestjson url, true do |readme_json|
        content = readme_json["content"]
        readme = Base64.decode64(content)
        filename = file_name_from(i, readme_data)
        readmes_content.push(filename: filename, content: readme)
      end
      hydra.queue req
    end
    hydra.run

    readmes_content
  end

private

  def priority_of(path)
    EXTENSIONS_PRIORITIES.index{|pattern| pattern =~ File.basename(path)}
  end

  def file_name_from(i, readme_data)
    data = [
      sprintf("%.4d", i+1),
      readme_data[:url].split("/")[4],
      readme_data[:url].split("/")[5],
      readme_data[:extension]
    ]
    "#{data.join(".-.")}.txt"
  end
end

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

class Cache
  def initialize
    @redis = Redis.new url: ENV["REDISTOGO_URL"]
  end

  def get(request)
    response_body = @redis.get url_id(request.base_url)
    if response_body
      Typhoeus::Response.new(return_code: :ok, code: 200, body: from_gzip(response_body))
    else
      nil
    end
  end

  def set(request, response)
    gziped = to_gzip(response.body)
    if gziped.size <= 660000
      fifteen_minutes = 15*60
      @redis.setex url_id(request.base_url), fifteen_minutes, gziped
    end
  rescue Exception => e
    # probably because of redis memory limit
    puts "Couldn't cache #{request.base_url}"
  end

  def url_id(url)
    uri = URI.parse url
    uri.query = uri.query.gsub(/client_id=[^=]*&client_secret=[^=]*/, "")
    uri.path + "?" + uri.query
  end

  def to_gzip(content)
    Base64.encode64(content)
  end

  def from_gzip(content)
    Base64.decode64(content)
  end
end

Typhoeus::Config.cache ||= Cache.new

module UrlBuilder
  extend self

  # We set domains to make request in parallel
  DOMAINS = [
    "api.github.com",
    "corpus-retrieval-slave1.herokuapp.com",
    "corpus-retrieval-slave2.herokuapp.com",
    "corpus-retrieval-slave3.herokuapp.com",
    "corpus-retrieval-slave4.herokuapp.com",
  ]

  # Build urls to be passed for the domains?
  def build(url, page=nil, sort=nil, order=nil)
    uri = URI.parse(url)
    domain = next_domain
    query = uri.query && "?" + uri.query || ""
    url = "https://" + domain + uri.path + query
    if url.include? "?"
      url = url + "&" + client_params
    else
      url = url + "?" + client_params
    end

    if sort
      url = url + "&sort=#{sort}"
    end

    if order
      url = url + "&order=#{order}"
    end

    if page
      url = url + "&page=#{page}"
    end

    return url
  end

private

  # make the counts of the url to be spread by the domains
  def next_domain
    @domainindex ||= 0
    domain = DOMAINS[@domainindex]
    @domainindex = (@domainindex + 1) % DOMAINS.size
    domain
  end

  #define the parameters of the Auth Key needed to request information in Github
  def client_params
    cparams = client_env_vars
    "client_id=#{cparams[:client_id]}&client_secret=#{cparams[:client_secret]}"
  end
  #set the Auth key credentials. This will allow requests up to 5000.
  def client_env_vars
    @clientindex ||= 0

    params = {
      client_id: ENV['CLIENT_ID'].split(',')[@clientindex],
      client_secret: ENV['CLIENT_SECRET'].split(',')[@clientindex],
    }
    @clientindex += 1
    @clientindex = @clientindex % ENV['CLIENT_ID'].split(",").size
    params
  end
end
