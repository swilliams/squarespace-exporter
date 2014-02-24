require 'nokogiri'
require 'open-uri'

module Exporter
  class << self
    attr_accessor :xml

    def load(path)
      @xml = Nokogiri::XML File.read(path)
      @xml
    end

    def all_posts
      posts = all_items_of_type 'post'
      posts.map { |p| parse_post p }
    end

    def all_attachments
      attachments = all_items_of_type 'attachment'
      attachments.map { |a| parse_attachment a }
    end

    def parse_post(element)
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

    def parse_attachment(element)
      element.css('wp|attachment_url').inner_html
    end

    def change_image_urls(item)
      replace_with = '/images/assets/'
      re = /http:\/\/static.squarespace.com\/static\/[\w]+\/[\w]+\/[\w]+\/[\w]+\//
      item.content.gsub! re, replace_with
    end

    def create_folders
      path = File.expand_path '../export', __FILE__
      Dir.mkdir path
      Dir.mkdir "#{path}/attachments"
      Dir.mkdir "#{path}/posts"
    end

    def filename_from_url(url)
      File.basename url
    end

    def honk
      puts "HONK"
    end

    def download_attachments
      create_folders
      all_attachments.each do |a|
        to_path = File.expand_path "../export/attachments/#{filename_from_url a}", __FILE__
        File.open(to_path, 'wb') do |local_file|
          open(a, 'rb') do |remote_file|
            local_file.write(remote_file.read)
          end
        end
      end
    end

    private
    def all_items_of_type(type)
      items = @xml.css 'channel > item'
      results = []
      items.each do |item|
        results << item if is_type? type, item
      end
      results
    end

    def is_type?(type, item)
      item.css('wp|post_type').inner_html == type
    end


  end

  class Post
    attr_accessor :title, :content, :published, :tags
  end
end
