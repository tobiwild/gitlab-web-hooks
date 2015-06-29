$LOAD_PATH << File.expand_path(File.dirname(__FILE__)) + '/lib'

require 'hooks/reviewboard'
require 'git_service'
require 'reviewboard/client'

Dotenv.load

post '/' do
  request.body.rewind
  @request_payload = JSON.parse request.body.read
  # ap @request_payload

  reviewboard_hook.process(@request_payload)
end

def reviewboard_hook
  @reviewboard_hook ||= Hooks::Reviewboard.new(
    Reviewboard::Client.new(
      base_uri: ENV['REVIEWBOARD_URI'],
      basic_auth: {
        username: ENV['REVIEWBOARD_USER'],
        password: ENV['REVIEWBOARD_PASSWORD']
      }
    ),
    Gitlab.client(
      endpoint: ENV['GITLAB_ENDPOINT'],
      private_token: ENV['GITLAB_PRIVATE_TOKEN']
    ),
    GitService.new(ENV['GIT_REPO_PATH']),
    label: ENV['GITLAB_TRIGGER_LABEL']
  )
end
