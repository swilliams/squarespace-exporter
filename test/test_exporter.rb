require 'test/unit'
require 'nokogiri'
require 'pry'
require_relative '../script'

class ImporterTest < Test::Unit::TestCase
  def setup
    path = (File.expand_path('../factory.xml', __FILE__))
    Exporter::Post.author = nil
    @xml = Exporter.load path
  end

  def teardown
    path = File.expand_path '../../export', __FILE__
    FileUtils.rm_rf(path) if File.directory? path
  end

  def test_load
    author = @xml.css 'channel > title'
    assert_equal 'Scott Williams', author.inner_html
  end

  def test_each_blog
    results = Exporter.all_posts
    assert_equal 2, results.count
  end

  def test_parsed_item
    post = Exporter.all_posts.first
    assert_equal 'Demystifying Ruby DSLs — Part 2', post.title
    assert(post.content.nil? == false)
    assert(post.content.include?('CDATA') == false)
    assert_equal '2014-02-21 19:34:05', post.published
    assert_equal ['ruby','code'], post.tags
    assert_equal '2014-02-21-demystifying-ruby-dsls-part-2.html', post.filename
  end

  def test_parse_author
    Exporter.all_posts
    assert_equal 'Scott Williams', Exporter::Post.author
  end

  def test_switched_images_over
    post = Exporter.all_posts.first
    assert(post.content.include?('static.squarespace.com') == false)
    assert(post.content.include?('images/assets'))
  end

  def test_self_ref_urls
    post = Exporter.all_posts.first
    assert(post.content.include?('blog.swilliams.me') == false)
    assert(post.content.include?('/words'))
  end

  def test_extracted_attachments
    results = Exporter.all_attachments
    assert_equal(2, results.count)
    assert_equal 'http://static.squarespace.com/static/503c2d51c4aaa390413b1112/50424765e4b05fbf2352555a/5307a928e4b0bba2c5d78d0d/1393010996562/cashew.jpg', results.first
  end

  def test_filename_extraction
    url = 'http://static.squarespace.com/static/503c2d51c4aaa390413b1112/50424765e4b05fbf2352555a/5307a928e4b0bba2c5d78d0d/1393010996562/cashew.jpg'
    filename = Exporter.filename_from_url url
    assert_equal 'cashew.jpg', filename
  end

  def test_export_exists
    Exporter.create_folders
    path = File.expand_path('../../export', __FILE__)
    assert File.directory? path
  end

  def test_generated_post_includes_header
    post = Exporter::Post.new
    Exporter::Post.author = 'Scott Williams'
    post.title = 'Sample Post'
    post.content = 'derp derp'
    post.published = '2014-02-21 19:34:05'
    post.tags = %w(Ruby Code)
    header = %q(---
layout: post
title: "Sample Post"
date: 2014-02-21 19:34:05
comments: false
author: Scott Williams
categories: [Ruby,Code]
---
derp derp)
    assert_equal header, post.generate
  end
end
