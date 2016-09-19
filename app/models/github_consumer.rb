module GithubConsumer
  extend self

  def get_readmes(query)
    repositories_urls = RepositoriesSearcher.get_all_repositories_urls(query)
    ReadmesSearcher.get_readmes_of_repositories(repositories_urls)
  end
end

