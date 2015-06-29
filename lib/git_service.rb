require 'digest/sha1'
require 'open3'
require 'tempfile'

# class
class GitService
  class Exception < StandardError
  end

  def initialize(repo_path)
    @repo_path = repo_path
  end

  def create_diff(repo, from, to)
    Dir.mkdir(@repo_path) unless Dir.exist?(@repo_path)
    hash = Digest::SHA1.hexdigest(repo)
    repo_path = File.join(@repo_path, hash)
    if Dir.exist?(repo_path)
      command 'git remote update --prune', chdir: repo_path
    else
      command 'git', 'clone', '--mirror', repo, hash, chdir: @repo_path
    end
    file = Tempfile.new('git_diff')

    begin
      command "git diff --full-index #{from}...#{to} > #{file.path}", chdir: repo_path

      yield file.path
    ensure
      file.unlink
    end
  end

  private

  def command(*command)
    ret = ''
    Open3.popen3(*command) do |_stdin, stdout, stderr, wait_thr|
      ret = stdout.gets
      raise Exception.new(stderr.gets.chomp) unless wait_thr.value == 0
    end
    ret
  end
end
