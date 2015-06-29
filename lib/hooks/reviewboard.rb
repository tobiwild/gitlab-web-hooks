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

      review_id = review_id_from_comments(
        attr.fetch('source_project_id'),
        attr.fetch('id')
      )

      unless review_id.nil?
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
          @gitlab.create_merge_request_comment(
            attr.fetch('source_project_id'),
            attr.fetch('id'),
            "REVIEW_ID: #{review_id}"
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
          submit_as: merge_request.fetch('user').fetch('username')
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

    def review_id_from_comments(pid, mid)
      @gitlab.merge_request_comments(pid, mid).each do |comment|
        return $1.to_i if /REVIEW_ID: (\d+)/.match(comment.note)
      end
      nil
    end
  end
end
