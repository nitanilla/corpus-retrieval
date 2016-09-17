module GithubConsumer
  module ReadmesSearcher
    extend self

    README_PATTERN = %r{^readme.?([^.]*)$}i
    EXTENSIONS_PRIORITIES = [/\.md$/, /\.rst$/, /\.html$/, /\..*doc$/, /\..*$/, /^[^.]*$/]

    def get_readmes_of_repositories(repositories_urls)
      unrecognizeds = []
      client = Client.new
      readmes_data = []
      repositories_urls.each_with_index do |head_url, i|
        readme_data = nil
        url = UrlBuilder.build(head_url)
        client.register_request url do |root_json|
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
      end
      client.run_requests

      readmes_content = []

      client = Client.new
      readmes_data.compact.each.with_index do |readme_data, i|
        url = UrlBuilder.build readme_data[:url]
        client.register_request url do |readme_json|
          content = readme_json["content"]
          readme = Base64.decode64(content)
          filename = file_name_from(i, readme_data)
          readmes_content.push(filename: filename, content: readme)
        end
      end
      client.run_requests
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
end
