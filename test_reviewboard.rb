$LOAD_PATH << File.expand_path(File.dirname(__FILE__)) + '/lib'

require 'reviewboard/client'
require 'pry'

client = Reviewboard::Client.new(
  base_uri: 'http://localhost:8000',
  basic_auth: {
    username: 'admin',
    password: 'admin'
  }
)

# response = client.sync_review_request(
#   create_params: {
#     :repository => 'mappy'
#   }
# )

# response = client.review_requests

# response = client.upload_diff(1, '/tmp/foo.diff')

binding.pry
