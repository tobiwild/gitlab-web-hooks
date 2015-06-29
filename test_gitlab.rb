require 'gitlab'
require 'pry'

Gitlab.configure do |config|
  config.endpoint = 'http://localhost:10080/api/v3'
  config.private_token = 'tdUyLoh4vMhDpnMGusx1'
end

projects = Gitlab.projects
comments = Gitlab.merge_request_comments(3, 3)

binding.pry
