require "typhoeus"
require "base64"
require "zip"
require "redis"
require "json"

module GithubConsumer
  extend self
  MAX_PAGES = 10

  PARAMS_COMBINATIONS = [
    {sort: nil, order: nil}, # best match
    {sort: "stars", order: "desc"},
    {sort: "forks", order: "desc"},
    {sort: "stars", order: "asc", reversed: true},
    {sort: "forks", order: "asc", reversed: true}
  ]

  README_PATTERN = %r{^readme.?([^.]*)$}i

  EXTENSIONS_PRIORITIES = [/\.md$/, /\.rst$/, /\.html$/, /\..*doc$/, /\..*$/, /^[^.]*$/]

  def get_readmes(query)
    repos_url = "https://api.github.com/search/repositories?q=#{query.gsub(" ","+")}+in:readme&per_page=100"
    all_head_urls = []
    hydra = newhydra
    items = []
    for params in PARAMS_COMBINATIONS
      url = UrlBuilder.build(repos_url, 1, params[:sort], params[:order])
      req = requestjson url do |first_page_json|
        items = get_remaning_pages(repos_url, first_page_json, params)

        # une as urls
        all_head_urls |= head_urls_from(items, params[:reversed])
      end
      hydra.queue req
    end
    hydra.run

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

    puts "first_page: #{first_page_json.inspect}"
    items = first_page_json["items"]
    hydra = newhydra
    for page in 2..total_pages
      page_url = UrlBuilder.build(repos_url, page, params[:sort], params[:order])
      request = requestjson page_url do |json|
        puts "page_url: #{page_url}"
        puts "page_json: #{json.inspect}"
        items += json["items"]
      end
      hydra.queue request
    end
    hydra.run
    items
  end

  def count_matches_on(readme, query)
    pattern = /#{query.gsub(/ +/, "[^0-9A-Za-z]")}/i
    readme.scan(pattern).size
  end

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

  def newhydra
    Typhoeus::Hydra.new(max_concurrency: 14)
  end

  def requestjson(url, log=false, &block)
    request = Typhoeus::Request.new url
    request.on_complete do |response|
      if response.success?
        puts "[OK-#{response.cached?}] #{url}"
        block.call(JSON.parse(response.body))
      else
        puts "[FAIL-#{response.cached?}] #{url}"
      end
    end
    request
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
      Typhoeus::Response.new(return_code: :ok, code: 200, body: response_body)
    else
      nil
    end
  end

  def set(request, response)
    two_hours = 2*60*60
    @redis.setex url_id(request.base_url), two_hours, response.body
  end

  def url_id(url)
    uri = URI.parse url
    uri.query = uri.query.gsub(/client_id=[^=]*&client_secret=[^=]*/, "")
    uri.path + "?" + uri.query
  end
end

Typhoeus::Config.cache ||= Cache.new

module UrlBuilder
  extend self

  DOMAINS = [
    "api.github.com",
    "corpus-retrieval-slave1.herokuapp.com",
    "corpus-retrieval-slave2.herokuapp.com",
    "corpus-retrieval-slave3.herokuapp.com",
    "corpus-retrieval-slave4.herokuapp.com",
  ]

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

  def next_domain
    @domainindex ||= 0
    domain = DOMAINS[@domainindex]
    @domainindex = (@domainindex + 1) % DOMAINS.size
    domain
  end

  def client_params
    cparams = client_env_vars
    "client_id=#{cparams[:client_id]}&client_secret=#{cparams[:client_secret]}"
  end

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
