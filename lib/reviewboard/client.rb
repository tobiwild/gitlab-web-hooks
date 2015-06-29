require 'httmultiparty'

module Reviewboard
  class Client
    class Exception < StandardError
    end

    include HTTMultiParty

    format :json

    def initialize(options = {})
      @options = options
    end

    def create_review_request(body)
      post('/api/review-requests/', {
        :body => body
      })
    end

    def update_review_request_draft(id, body)
      put("/api/review-requests/#{id}/draft/", {
        :body => body
      })
    end

    def upload_diff(review_id, path)
      post("/api/review-requests/#{review_id}/diffs/", {
        :body => {
          :path => File.new(path)
        }
      })
    end

    def diffs(review_id)
      get("/api/review-requests/#{review_id}/diffs/")
    end

    def sync_review_request(options)
      if options.key?(:create_params)
        review_id = create_review_request(options[:create_params])
                    .fetch('review_request')
                    .fetch('id')
      else
        review_id = options.fetch(:review_id)
      end

      upload_diff(review_id, options[:diff]) if options.key?(:diff)
      if options.key?(:draft_params)
        update_review_request_draft(review_id, options[:draft_params])
      end

      review_id
    end

    def last_diff_uri(review_id)
      count = diffs(review_id).fetch('total_results')
      base = "#{@options.fetch(:base_uri)}/r/#{review_id}/diff"

      return "#{base}/#{count - 1}-#{count}" if count > 1
      "#{base}/1"
    end

    def review_request(review_id)
      get("/api/review-requests/#{review_id}/").fetch('review_request')
    end

    def review_requests(query = {})
      get('/api/review-requests/', {
        :query => query
      })
    end

    private

    def post(*args)
      request(:post, *args)
    end

    def get(*args)
      request(:get, *args)
    end

    def put(*args)
      request(:put, *args)
    end

    def request(method, path, options = {})
      response = self.class.send(method, path, @options.merge(options))
      raise Exception.new(response) unless (200..299).include?(response.code)
      response
    end
  end
end
