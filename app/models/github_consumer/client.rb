module GithubConsumer
  class Client
    MAX_RETRIES = 3

    def initialize
      @hydra = build_hydra
      @retry_count = 0
    end

    def register_request(url, &block)
      request = Typhoeus::Request.new url #(rand(50) >= 25 ? "xpto" + url : url)
      request.on_complete do |response|
        if response.success?
          body = response.body
          json = JSON.parse(body) rescue nil
          if !json.nil? && (!json.is_a?(Hash) || json['message'].nil?)
            puts "[OK-#{response.cached?}] #{url}"
            block.call(json)
          else
            @failed_requests << [url, block]
            puts "[ERR-#{response.code}] #{url} #{body.inspect}"
          end
        else
          @failed_requests << [url, block]
          puts "[FAIL-#{response.cached?}] #{url}"
        end
      end
      @hydra.queue request
      request
    end

    def run_requests
      @failed_requests = []
      @hydra.run
      while !@failed_requests.empty? && @retry_count < MAX_RETRIES
        puts "[RETRY] Retrying #{@failed_requests.size} failing requests"
        @failed_requests.each do |(url, block)|
          self.register_request(url, &block)
        end
        @failed_requests = []
        @hydra.run
        @retry_count += 1
      end
    end

    def build_hydra
      Typhoeus::Hydra.new(max_concurrency: 14)
    end
  end
end
