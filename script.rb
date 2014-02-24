require 'nokogiri'
require 'open-uri'

module Exporter
  class << self
    attr_accessor :xml

    def load(path)
      @xml = Nokogiri::XML File.read(path)
      parse_author
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

    def parse_author
      Exporter::Post.author = @xml.css('channel > title').inner_html
    end

    def parse_post(element)
      post = Post.new
      post.title = element.css('title').inner_html
      post.content = element.css('content|encoded').inner_html
      post.published = element.css('wp|post_date').inner_html
      post.filename = parse_filename element
      post.tags = element.css('category[domain=post_tag]').map do |t|
        t.attr 'nicename'
      end
      change_image_urls post
      change_self_ref_urls post
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

    def change_self_ref_urls(item)
      replace_with = '/words'
      re = /http:\/\/blog\.swilliams\.me\/words/
      item.content.gsub! re, replace_with
    end

    def parse_filename(element)
      base_filename = File.basename element.css('link').inner_html
      datetime = DateTime.parse element.css('wp|post_date').inner_html
      "#{datetime.strftime "%Y-%m-%d"}-#{base_filename}.html"
    end

    def export_path
      File.expand_path '../export', __FILE__
    end

    def attachment_path
      "#{export_path}/attachments"
    end

    def post_path
      "#{export_path}/posts"
    end

    def create_folders
      Dir.mkdir export_path 
      Dir.mkdir attachment_path 
      Dir.mkdir post_path
    end

    def filename_from_url(url)
      File.basename url
    end

    def download_attachments
      create_folders
      all_attachments.each do |a|
        puts "Downloading #{a}"
        to_path = "#{attachment_path}/#{filename_from_url a}"
        File.open(to_path, 'wb') do |local_file|
          open(a, 'rb') do |remote_file|
            local_file.write(remote_file.read)
          end
        end
      end
    end

    def export_posts
      create_folders
      all_posts.each do |p|
        to_path = "#{post_path}/#{p.filename}"
        File.open(to_path, 'w') { |f| f.write p.generate }
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
    attr_accessor :title, :content, :published, :tags, :filename
    
    class << self
      attr_accessor :author
    end

    def generate
      %{---
layout: post
title: "#{@title}"
date: #{@published}
comments: false
author: #{self.class.author}
categories: [#{@tags.join(',')}]
---
#{@content}}
    end
  end
end
