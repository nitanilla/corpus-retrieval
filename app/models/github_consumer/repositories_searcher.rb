module GithubConsumer
  module RepositoriesSearcher
    extend self

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
      client = Client.new
      items = []
      PARAMS_COMBINATIONS.each_with_index do |params, i|
        url = UrlBuilder.build(repos_url, 1, params[:sort], params[:order])
        client.register_request url do |first_page_json|
          items = get_remaning_pages(repos_url, first_page_json, params)

          # une as urls
          all_head_urls[i] = head_urls_from(items, params[:reversed])
        end
      end
      client.run_requests
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
      client = Client.new
      (2..total_pages).each do |page|
        page_url = UrlBuilder.build(repos_url, page, params[:sort], params[:order])
        client.register_request page_url do |json|
          items[page] = json["items"]
        end
      end
      client.run_requests
      
      items.compact.flatten
    end
  end
end
