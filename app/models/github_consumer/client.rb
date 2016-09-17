module GithubConsumer
  class Client
    def initialize
      @hydra = Typhoeus::Hydra.new(max_concurrency: 14)
    end

    def register_request(url, &block)
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
      @hydra.queue request
      request
    end

    def run_requests
      @hydra.run
    end
  end
end
