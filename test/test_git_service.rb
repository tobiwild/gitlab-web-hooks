require 'helper'
require 'fileutils'
require 'git_service'

describe GitService do
  before do
    @temp_path = File.join(File.dirname(__FILE__), 'temp')
    Dir.mkdir(@temp_path)

    @repo_path = File.join(@temp_path, 'repositories')
    @service = GitService.new(@repo_path)

    @src_repo = File.join(File.dirname(__FILE__), 'fixtures', 'src.git')
  end

  after do
    FileUtils.rm_rf @temp_path
  end

  describe 'create_diff' do
    it 'creates diff' do
      diff_file = nil
      @service.create_diff(@src_repo, 'master', 'branch1') do |file|
        assert_exists file
        assert_includes File.open(file).read, '+++ b/branch1.txt'
        diff_file = file
      end
      refute_nil diff_file
      refute_exists diff_file
    end

    it 'works with multiple diffs' do
      @service.create_diff(@src_repo, 'master', 'branch1') {}
      @service.create_diff(@src_repo, 'master', 'branch1') do |file|
        assert_exists file
        assert_includes File.open(file).read, '+++ b/branch1.txt'
      end
    end

    it 'fails for unknown repo' do
      assert_raises GitService::Exception do
        @service.create_diff('/unknown/repo', 'master', 'branch1') {}
      end
    end

    it 'fails for unknown from-branch' do
      assert_raises GitService::Exception do
        @service.create_diff(@src_repo, 'unknown', 'branch1') {}
      end
    end

    it 'fails for unknown to-branch' do
      assert_raises GitService::Exception do
        @service.create_diff(@src_repo, 'master', 'unknown') {}
      end
    end

  end

end
