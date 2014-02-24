require 'test/unit'
require 'nokogiri'
require 'pry'
require_relative '../script'

class ImporterTest < Test::Unit::TestCase
  def setup
    path = (File.expand_path('../factory.xml', __FILE__))
    @xml = Exporter.load path
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
  end

  def test_switched_images_over
    post = Exporter.all_posts.first
    assert(post.content.include?('static.squarespace.com') == false)
    assert(post.content.include?('images/assets'))
  end

  def test_extracted_attachments
    results = Exporter.all_attachments
    assert_equal(2, results.count)
    assert_equal 'http://static.squarespace.com/static/503c2d51c4aaa390413b1112/50424765e4b05fbf2352555a/5307a928e4b0bba2c5d78d0d/1393010996562/cashew.jpg', results.first
  end
end
