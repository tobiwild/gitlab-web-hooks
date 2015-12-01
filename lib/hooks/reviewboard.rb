module Hooks
  # Transfers merge request changes to reviewboard
  class Reviewboard
    def initialize(reviewboard, gitlab, git, options = {})
      @reviewboard = reviewboard
      @gitlab = gitlab
      @git = git
      @options = options
    end

    def process(merge_request)
      attr = merge_request.fetch('object_attributes')

      return unless label_matches?(attr)

      review_id = attr.fetch('description')[/(?<=REVIEW_ID: )\d+/]
      review_id = review_id.to_i unless review_id.nil?

      unless review_id.nil?
        @reviewboard.update_review_request(
          review_id,
          status: if %w(merged closed).include?(attr.fetch('state'))
                    'submitted'
                  else
                    'pending'
                  end
        )
        review = @reviewboard.review_request(review_id)
        return if review.fetch('commit_id') == attr.fetch('last_commit').fetch('id')
      end

      @git.create_diff(
        attr.fetch('source').fetch('ssh_url'),
        attr.fetch('target_branch'),
        attr.fetch('source_branch')
      ) do |file|
        if review_id.nil?
          review_id = create_review_request(merge_request, file)
          @gitlab.update_merge_request(
            attr.fetch('source_project_id'),
            attr.fetch('id'),
            description:
              "#{attr.fetch('description')}\r\nREVIEW_ID: #{review_id}".strip
          )
        else
          update_review_request(review_id, merge_request, file)
        end
      end

      @gitlab.create_merge_request_comment(
        attr.fetch('source_project_id'),
        attr.fetch('id'),
        @reviewboard.last_diff_uri(review_id)
      )
    end

    def label_matches?(attr)
      return true unless @options.key?(:label)

      @gitlab.merge_request(
        attr.fetch('source_project_id'),
        attr.fetch('id')
      ).labels.include?(@options[:label])
    end

    def update_review_request(review_id, merge_request, file)
      attr = merge_request.fetch('object_attributes')

      @reviewboard.sync_review_request(
        review_id: review_id,
        draft_params:
        {
          public: true,
          commit_id: attr.fetch('last_commit').fetch('id')
        },
        diff: file
      )
    end

    def create_review_request(merge_request, file)
      attr = merge_request.fetch('object_attributes')
      repo = attr.fetch('source')

      @reviewboard.sync_review_request(
        create_params:
        {
          repository: repo.fetch('name'),
          submit_as: ldap_uid(attr.fetch('author_id')) || merge_request.fetch('user').fetch('username')
        },
        draft_params:
        {
          branch: attr.fetch('source_branch'),
          summary: attr.fetch('title'),
          description: attr.fetch('url'),
          public: true,
          commit_id: attr.fetch('last_commit').fetch('id')
        },
        diff: file
      )
    end

    def ldap_uid(user_id)
      @gitlab
        .user(user_id)
        .identities.find { |i| i.fetch('provider') == 'ldapmain' }
        .tap { |o| return nil if o.nil? }
        .fetch('extern_uid')[/(?<=uid=)[^,]+/]
    end
  end
end
