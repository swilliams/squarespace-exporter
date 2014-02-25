require 'rake/testtask'
require_relative 'script'

Rake::TestTask.new do |t|
  t.libs << 'test'
  #puts t.libs
end

desc "Run tests"
task :default => :test

task :derp do
  url = ENV["URL"]
  response = Exporter.load_url url
  post = Exporter.handle_response response
  unless post.nil?
    post.download_attachments
  end
end

task :clean do
  path = File.expand_path '../export', __FILE__
  FileUtils.rm_rf(path) if File.directory? path
end

