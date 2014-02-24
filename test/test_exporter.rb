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
end
