require 'rake/testtask'
require_relative 'script'

Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test

# Gets a single post and exports it.
task :single do
  url = ENV["URL"]
  response = Exporter.load_url url
  post = Exporter.handle_response response
  unless post.nil?
    post.export
  end
end

# Walks through the post history and exports them all.
task :crawl do
  url = ENV["URL"]
  Exporter.get_all_posts url
end

# Removes the exported files and folders.
task :clean do
  path = File.expand_path '../export', __FILE__
  FileUtils.rm_rf(path) if File.directory? path
end

