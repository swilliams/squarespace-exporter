require 'rake/testtask'
require_relative 'script'

Rake::TestTask.new do |t|
  t.libs << 'test'
  #puts t.libs
end

desc "Run tests"
task :default => :test

task :download_attachments do
  Exporter.load '/Users/swilliams/code/squarespace-export/test/factory.xml'
  Exporter.download_attachments
end

task :export_posts do
  Exporter.load '/Users/swilliams/code/squarespace-export/test/factory.xml'
  Exporter.export_posts
end

task :clean do
  path = File.expand_path '../export', __FILE__
  FileUtils.rm_rf(path) if File.directory? path
end
