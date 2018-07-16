module GithubConsumer
  module IssuesSearcher
    extend self

    MAX_PAGES = 10

    PARAMS_COMBINATIONS = [
      {sort: nil, order: nil, reversed: false}, # best match
      {sort: "comments", order: "desc", reversed: false},
      {sort: "created", order: "desc", reversed: false},
      {sort: "updated", order: "desc", reversed: false},
      {sort: "comments", order: "asc", reversed: true},
      {sort: "created", order: "asc", reversed: true},
      {sort: "updated", order: "asc", reversed: true}
    ]

    def get_all_issues(query)
      repos_url = "https://api.github.com/search/issues?q=#{query.gsub(" ","+")}&per_page=100"
      all_issues = []
      client = Client.new
      items = []
      PARAMS_COMBINATIONS.each_with_index do |params, i|
        url = UrlBuilder.build(repos_url, 1, params[:sort], params[:order])
        client.register_request url do |first_page_json|
          items = get_remaning_pages(repos_url, first_page_json, params)

          # une as urls
          all_issues[i] = params[:reversed] ? items.reverse : items
        end
      end
      client.run_requests
      joined_issues = all_issues.flatten.uniq{|issue_json| issue_json["id"]}

      get_comments(joined_issues)
      joined_issues
    end
  private

    def get_comments(issues)
      client = Client.new
      issues.each do |issue|
        issue["comments_all"] = []
        comments_url = issue["comments_url"] + "?per_page=100"
        pages_amount = (issue["comments"].to_i / 100.0).ceil.to_i
        (1..pages_amount).each do |page|
          comments_url = UrlBuilder.build(comments_url, page)
          client.register_request comments_url do |comments_json|
            issue["comments_all"] += comments_json
          end
        end
      end
      client.run_requests
    end

    def get_remaning_pages(repos_url, first_page_json, params)
      total_items = first_page_json["total_count"]
      total_pages = [(total_items / 100.0).ceil.to_i, MAX_PAGES].min

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
