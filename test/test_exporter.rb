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
end
