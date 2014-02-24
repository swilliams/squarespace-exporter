require 'nokogiri'

module Exporter
  class << self
    attr_accessor :xml

    def load(path)
      @xml = Nokogiri::XML File.read(path)
      @xml
    end

    def all_posts
      items = @xml.css 'channel > item'
      posts = []
      items.each do |item| 
        posts << parse_item(item) if is_post? item
      end
      posts
    end

    def parse_item(element)
      post = Post.new
      post.title = element.css('title').inner_html
      post.content = element.css('content|encoded').inner_html
      post.published = element.css('wp|post_date').inner_html
      post.tags = element.css('category[domain=post_tag]').map do |t|
        t.attr 'nicename'
      end
      change_image_urls post
      post
    end

    def is_post?(item)
      item.css('wp|post_type').inner_html == 'post'
    end

    def change_image_urls(item)
      replace_with = '/images/assets/'
      re = /http:\/\/static.squarespace.com\/static\/[\w]+\/[\w]+\/[\w]+\/[\w]+\//
      item.content.gsub! re, replace_with
    end
  end

  class Post
    attr_accessor :title, :content, :published, :tags
  end
end
