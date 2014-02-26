require 'rake/testtask'
require_relative 'script'

Rake::TestTask.new do |t|
  t.libs << 'test'
  #puts t.libs
end

desc "Run tests"
task :default => :test

task :single do
  url = ENV["URL"]
  response = Exporter.load_url url
  post = Exporter.handle_response response
  unless post.nil?
    post.export
  end
end

task :crawl do
  url = ENV["URL"]
  Exporter.get_all_posts url
end

task :clean do
  path = File.expand_path '../export', __FILE__
  FileUtils.rm_rf(path) if File.directory? path
end

