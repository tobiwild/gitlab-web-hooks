require 'helper'
require 'json'
require 'hooks/reviewboard'
require 'ostruct'

# Hooks
module Hooks
  describe Reviewboard do
    before do
      @reviewboard = Minitest::Mock.new
      @gitlab = Minitest::Mock.new
      @git = Minitest::Mock.new

      @hook = Reviewboard.new(
        @reviewboard, @gitlab, @git, label: 'reviewboard'
      )

      file = File.join(
        File.dirname(__FILE__), '..', 'fixtures', 'merge_request.json')
      @merge_request = JSON.parse File.open(file).read
    end

    it 'does not sync when label is different' do
      @gitlab.expect(
        :merge_request,
        OpenStruct.new(labels: ['foo']),
        [3, 4]
      )

      @hook.process(@merge_request)
    end

    describe 'sync review' do
      before do
        @git.expect(:create_diff, nil) do |&block|
          block.call('/some/diff')
          true
        end

        @reviewboard.expect(
          :last_diff_uri, 'http://localhost:8000/r/1/diff/2-3/', [42])

        @gitlab.expect(
          :merge_request,
          OpenStruct.new(labels: ['reviewboard']),
          [3, 4]
        )

        @gitlab.expect(
          :user,
          OpenStruct.new(
            identities: [
              {
                'provider' => 'ldapmain',
                'extern_uid' => 'uid=bernd.root,ou=Users'
              }
            ]
          ),
          [1]
        )
      end

      it 'creates new review request' do
        @gitlab.expect(:update_merge_request, nil, [
          3, 4, description: "some new feature\r\nREVIEW_ID: 42"
        ])
        @reviewboard.expect(:sync_review_request, 42, [
          {
            create_params:
            {
              repository: 'mappy',
              submit_as: 'bernd.root'
            },
            draft_params:
            {
              branch: 'feature',
              summary: 'Feature2',
              description: 'http://localhost:10080/root/mappy/merge_requests/2',
              public: true,
              commit_id: '94a6385c51d6134d6b95b30a69b4fe9579196152'
            },
            diff: '/some/diff'
          }
        ])
        @gitlab.expect(:create_merge_request_comment, nil, [
          3, 4, 'http://localhost:8000/r/1/diff/2-3/'
        ])

        @hook.process(@merge_request)

        @gitlab.verify
        @reviewboard.verify
      end

      describe 'update review' do
        before do
          @merge_request['object_attributes']['description'] =
            'bla bla REVIEW_ID: 42 bla bla'
          @reviewboard.expect(
            :update_review_request,
            nil,
            [42, status: 'pending']
          )
        end

        it 'reads active review id from comments and updates review' do
          @reviewboard.expect(
            :review_request,
            { 'commit_id' => 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx' },
            [42]
          )

          @reviewboard.expect(:sync_review_request, 1, [
            {
              review_id: 42,
              draft_params:
              {
                public: true,
                commit_id: '94a6385c51d6134d6b95b30a69b4fe9579196152'
              },
              diff: '/some/diff'
            }
          ])
          @gitlab.expect(:create_merge_request_comment, nil, [
            3, 4, 'http://localhost:8000/r/1/diff/2-3/'
          ])

          @hook.process(@merge_request)

          @reviewboard.verify
        end

        it 'does not sync when commit is already synced' do
          @reviewboard.expect(
            :review_request,
            { 'commit_id' => '94a6385c51d6134d6b95b30a69b4fe9579196152' },
            [42]
          )

          @hook.process(@merge_request)
        end
      end
    end
  end
end
