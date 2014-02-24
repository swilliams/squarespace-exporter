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
        posts << item if is_post? item
      end
      posts
    end

    def is_post?(item)
      item.css('wp|post_type').inner_html == 'post'
    end
  end
end
