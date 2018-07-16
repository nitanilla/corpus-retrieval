module GithubConsumer
  extend self

  def get_readmes(query)
    repositories_urls = RepositoriesSearcher.get_all_repositories_urls(query)
    ReadmesSearcher.get_readmes_of_repositories(repositories_urls)
  end

  def get_issues(query)
    issues = IssuesSearcher.get_all_issues(query)
    [
      {
        filename: "issues.json",
        content: JSON.dump(issues),
      }
    ]
  end
end

