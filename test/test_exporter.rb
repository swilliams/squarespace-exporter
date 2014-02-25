require 'test/unit'
require 'webmock/test_unit'
require 'pry'
require 'reverse_markdown'
require_relative '../script'

class ImporterTest < Test::Unit::TestCase
  def setup
    @url = 'http://blog.swilliams.me/words/2014/2/21/demystifying-ruby-dsls-part-2'
    @json = File.read(File.expand_path('../factory.json', __FILE__))
    stub_request(:get, "#{@url}?format=json-pretty").to_return body: @json
  end

  def teardown
    FileUtils.rm_rf(Exporter.export_path) if File.directory? Exporter.export_path
  end

  def test_to_markdown
    post = Exporter.parse_post @json
    html = post.content
    md = ReverseMarkdown.parse html
    puts md
  end

  def test_load_url_returns_stuff
    response = Exporter.load_url @url
    assert(response.nil? == false)
  end

  def test_success_response
    response = Exporter.load_url @url
    assert(Exporter.response_is_success(response) == true)
  end

  def test_parse_post
    post = Exporter.parse_post @json
    assert(post.nil? == false)
    assert(post.author == 'Scott Williams')
    assert_equal( "Demystifying Ruby DSLs \u2014 Part 2", post.title)
    assert_equal(1393011245936, post.published)
    assert_equal("2014/2/21/demystifying-ruby-dsls-part-2", post.url)
    assert_equal(['ruby','code'], post.tags)
    assert_equal('http://blog.swilliams.me/words/2014/1/26/demystifying-ruby-dsls', post.next_url)
    assert(post.content.nil? == false)
    assert(post.content.empty? == false)
  end

  def test_unique_attachment_name
    filename = 'derp.png'
    assert(Exporter.unique_attachment_name(filename).include?(filename))
  end

  def test_scan_for_imgs
    post = Exporter.parse_post @json
    assert_equal(2, post.squarespace_images.count)
  end
  
  def test_image_tags_fixed
    post = Exporter::Post.new
    post.content = '<img class="thumb-image" alt="This is you with all the gerbil methods." data-src="/images/assets/cashew.jpg" data-image="/images/assets/cashew.jpg" data-image-dimensions="900x452" data-image-focal-point="0.5,0.5" data-load="false" data-image-id="5307a928e4b0bba2c5d78d0d" data-type="image">'
    post.fix_image_tags
    assert(post.content.include?('data-src') == false)
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

  def test_local_path_removes_hashes
    url = "derp-#img.jpg"
    post = Exporter::Post.new
    assert(post.local_path(url).include?("derp.jpg"))
  end

  def test_remove_squarespace_urls
    post = Exporter::Post.new
    post.content = 'thing <a href="http://blog.swilliams.me/words/foo">test</a>'
    post.change_self_ref_urls
    assert_equal 'thing <a href="/words/foo">test</a>', post.content
  end

  def test_generated_post_includes_header
    post = Exporter::Post.new
    post.author = 'Scott Williams'
    post.title = 'Sample Post'
    post.content = 'derp derp'
    post.published = 1393011245936
    post.tags = %w(Ruby Code)
    header = %q(---
layout: post
title: "Sample Post"
date: 2014-02-21
comments: false
author: Scott Williams
categories: [Ruby,Code]
---
derp derp)
    assert_equal header, post.generate
  end
end
