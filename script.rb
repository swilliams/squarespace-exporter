require 'json'
require 'securerandom'
require 'net/http'
require 'open-uri'
require 'nokogiri'
require 'pry'

# get start url
# get item -> author -> displayName
# item -> publishOn is int date
# item -> title
# item -> body
# item -> tags
# parse body to fix urls
# turn body into markdown?
# get next url from pagination -> nextItem -> urlId

module Exporter
  class << self
    attr_accessor :xml

    def get_all_posts(first_url)
      url = first_url
      while url
        response = Exporter.load_url url
        post = handle_response response
        unless post.nil?
          post.export
          url = post.next_url
        end
      end
    end

    def load_url(url)
      http = create_http url
      request = Net::HTTP::Get.new json_format_url(url)
      http.request request
    end

    def create_http(url)
      log 'GET', url
      uri = URI json_format_url(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http
    end
    
    def json_format_url(url)
      "#{url}?format=json-pretty"
    end

    def response_is_success(response)
      response.code == '200'
    end

    def parse_post(post_text)
      json = JSON.parse post_text
      post = Post.new

      root_url = json["website"]["authenticUrl"]

      post.author = json["item"]["author"]["displayName"]
      post.title = json["item"]["title"]
      post.published = json["item"]["publishOn"]
      post.url = json["item"]["urlId"]
      post.filename = "#{File.basename post.url}.html"
      post.tags = json["item"]["tags"] || []
      next_url = json["pagination"]["nextItem"]["fullUrl"] unless json["pagination"]["nextItem"].nil?
      post.next_url = "#{root_url}#{next_url}"
      post.content = json["item"]["body"]
      post.content = json["item"]["promotedBlock"] if post.content.nil? || post.content.empty?
      post
    end

    def handle_response(response)
      if response_is_success response
        parse_post response.body
      else
        log_error response
        return nil
      end
    end

    def log_error(response)
      log('ERROR', "#{response.code} - #{response.body}")
    end

    def log(type, message)
      puts "#{type} #{message}"
    end

    def parse_attachment(element)
      element.css('wp|attachment_url').inner_html
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
      Dir.mkdir export_path unless File.directory? export_path
      Dir.mkdir attachment_path unless File.directory? attachment_path
      Dir.mkdir post_path unless File.directory? post_path
    end

    def filename_from_url(url)
      File.basename url
    end

    def unique_attachment_name(filename)
      path = "#{attachment_path}/#{filename}"
      if File.exists? path
        path = "#{attachment_path}/#{SecureRandom.hex}-#{filename}"
      end
      path
    end
  end

  class Post
    attr_accessor :next_url, :title, :author, :content, :published, :tags, :filename, :url
    
    class << self
      attr_accessor :author
    end

    def image_regex
      /http:\/\/static.squarespace.com\/static\/[^"]+/
    end

    def squarespace_images
      @content.scan(image_regex).uniq
    end

    def local_path(img_url)
      path = Exporter.unique_attachment_name Exporter.filename_from_url(img_url)
      path.gsub '-#img', ''
      path << ".jpg" if File.extname(path).empty?
      path
    end

    def download_image(img_url)
      to_path = local_path img_url
      binding.pry
      @content.gsub! img_url, "/images/assets/#{File.basename(to_path)}"
      begin
        File.open(to_path, 'wb') do |local_file|
          open(img_url, 'rb') do |remote_file|
            local_file.write(remote_file.read)
          end
        end
      rescue Exception => ex
        Exporter.log 'ERROR', "#{img_url} #{ex}"
      end
    end

    def download_attachments
      Exporter.create_folders
      squarespace_images.each do |img_url|
        download_image img_url
      end
    end
    
    def change_self_ref_urls
      replace_with = '/words'
      re = /http:\/\/blog\.swilliams\.me\/words/
      @content.gsub! re, replace_with
    end

    def fix_image_tags
      re = /data-src/
      @content.gsub! re, 'src'
    end

    def export
      download_attachments
      change_self_ref_urls
      fix_image_tags
      to_path = "#{Exporter.post_path}/#{published_date}-#{@filename}"
      File.open(to_path, 'w') { |f| f.write generate }
    end

    def published_date
      t = Time.at(@published / 1000)
      t.strftime "%Y-%m-%d"
    end

    def strip_html
      stripper = HtmlStripper.new @content
      stripper.strip
    end

    def generate
      %{---
layout: post
title: "#{@title}"
date: #{published_date}
comments: false
author: #{@author}
categories: [#{@tags.join(',')}]
---
#{@content}}
    end
  end

  class HtmlStripper
    
    def initialize(html_text)
      @doc = Nokogiri::HTML(html_text)
    end

    def strip
      @doc.traverse do |node|
        method_name = "handle_#{node.name}"
        send method_name, node if respond_to? method_name
      end
      @doc.to_html indent: 2
    end

    def handle_div(node)
      node.attributes.each do |key, value|
        node.attributes[key].remove
      end
    end

    def handle_img(node)
      whitelist = %w(src alt width height)
      node.attributes.each do |key, value|
        node.attributes[key].remove unless whitelist.include? key
      end
    end

    def handle_span(node)
      node.attributes.each do |key, value|
        node.attributes[key].remove
      end
    end

    def handle_noscript(node)
      node.remove
    end
  end
end
