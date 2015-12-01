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
      @merge_request = merge_request

      return unless label_matches?

      @review_id = review_id
      unless @review_id.nil?
        update_review_request_status
        return if already_synced?
      end

      sync_diff
      set_last_diff_uri_in_merge_request
    end

    private

    def label_matches?
      return true unless @options.key?(:label)

      @gitlab.merge_request(
        attr.fetch('source_project_id'),
        attr.fetch('id')
      ).labels.include?(@options[:label])
    end

    def sync_diff
      @git.create_diff(
        attr.fetch('source').fetch('ssh_url'),
        attr.fetch('target_branch'),
        attr.fetch('source_branch')
      ) do |file|
        if @review_id.nil?
          @review_id = create_review_request(file)
          set_review_id_in_merge_request
        else
          update_review_request(file)
        end
      end
    end

    def update_review_request(file)
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

    def create_review_request(file)
      @reviewboard.sync_review_request(
        create_params:
        {
          repository: attr.fetch('source').fetch('name'),
          submit_as: review_request_submitter
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

    def attr
      @merge_request.fetch('object_attributes')
    end

    def review_id
      result = attr.fetch('description')[/(?<=REVIEW_ID: )\d+/]
      return result.to_i unless result.nil?
      nil
    end

    def review_request_submitter
      ldap_uid(attr.fetch('author_id')) ||
        @merge_request.fetch('user').fetch('username')
    end

    def ldap_uid(user_id)
      @gitlab
        .user(user_id)
        .identities.find { |i| i.fetch('provider') == 'ldapmain' }
        .tap { |o| return nil if o.nil? }
        .fetch('extern_uid')[/(?<=uid=)[^,]+/]
    end

    def update_review_request_status
      @reviewboard.update_review_request(
        @review_id,
        status: if %w(merged closed).include?(attr.fetch('state'))
                  'submitted'
                else
                  'pending'
                end
      )
    end

    def already_synced?
      review = @reviewboard.review_request(@review_id)
      review.fetch('commit_id') == attr.fetch('last_commit').fetch('id')
    end

    def set_review_id_in_merge_request
      @gitlab.update_merge_request(
        attr.fetch('source_project_id'),
        attr.fetch('id'),
        description:
        "#{attr.fetch('description')}\r\nREVIEW_ID: #{@review_id}".strip
      )
    end

    def set_last_diff_uri_in_merge_request
      @gitlab.create_merge_request_comment(
        attr.fetch('source_project_id'),
        attr.fetch('id'),
        @reviewboard.last_diff_uri(@review_id)
      )
    end
  end
end
