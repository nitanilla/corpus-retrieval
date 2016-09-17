module UrlBuilder
  extend self

  # We set domains to make request in parallel
  DOMAINS = ["api.github.com"] + ENV['SLAVES'].split(",")

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
