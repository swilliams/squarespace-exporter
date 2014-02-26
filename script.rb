require 'json'
require 'securerandom'
require 'net/http'
require 'open-uri'
require 'nokogiri'


# Probably need to split some of these out to their own files.
module Exporter
  class << self

    ### Crawls back through history of a blog, keeps going until the next_url is empty.
    # Actually, this throws an error when it's done with the last one. I'll fix it later.
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

    ### Fetches a URL with GET.
    def load_url(url)
      http = create_http url
      request = Net::HTTP::Get.new json_format_url(url)
      http.request request
    end

    ### Creates an http object based on the provided url.
    def create_http(url)
      log 'GET', url
      uri = URI json_format_url(url)
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      http
    end
    
    ### Squarespace does make it easy to get the meta data for a post by appending a format to any url.
    def json_format_url(url)
      "#{url}?format=json-pretty"
    end

    ### We only care about 200's here.
    def response_is_success(response)
      response.code == '200'
    end

    ### Parse the json to get the data we want.
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

    ### Do something intelligent with the http response.
    def handle_response(response)
      if response_is_success response
        parse_post response.body
      else
        log_error response
        return nil
      end
    end

    ### Log out an http error.
    def log_error(response)
      log('ERROR', "#{response.code} - #{response.body}")
    end

    ### Generic log message. Using good ole `puts` for now.
    def log(type, message)
      puts "#{type} #{message}"
    end

    ### Where the downloaded things go.
    def export_path
      File.expand_path '../export', __FILE__
    end

    ### Where attachments go.
    def attachment_path
      "#{export_path}/attachments"
    end

    ### Where posts go.
    def post_path
      "#{export_path}/posts"
    end

    ### Creates export folders.
    def create_folders
      Dir.mkdir export_path unless File.directory? export_path
      Dir.mkdir attachment_path unless File.directory? attachment_path
      Dir.mkdir post_path unless File.directory? post_path
    end

    ### Extract the filename info from a url.
    def filename_from_url(url)
      File.basename url
    end

    ### Make sure a downloaded file has a unique name.
    def unique_attachment_name(filename)
      path = "#{attachment_path}/#{filename}"
      if File.exists? path
        path = "#{attachment_path}/#{SecureRandom.hex}-#{filename}"
      end
      path
    end
  end

  ### A Post object. Contains the information we care about.
  class Post
    attr_accessor :next_url, :title, :author, :content, :published, :tags, :filename, :url
    
    ### Used to extract images hosted on squarespace's CDN.
    def image_regex
      /http:\/\/static.squarespace.com\/static\/[^"]+/
    end

    ### Get all of the images hosted on squarespace's CDN.
    def squarespace_images
      @content.scan(image_regex).uniq
    end

    ### Create a local path for a downloaded image. Some of the images in old posts had # in the filename, which makes things a little weird. Pull them out.
    def local_path(img_url)
      path = Exporter.unique_attachment_name Exporter.filename_from_url(img_url)
      path << ".jpg" if File.extname(path).empty?
      path.gsub '-#img', ''
    end

    ### Downloads an image and stores it locally. Needs to be refactored.
    def download_image(img_url)
      to_path = local_path img_url
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

    ### Download all images within a post.
    def download_attachments
      Exporter.create_folders
      squarespace_images.each do |img_url|
        download_image img_url
      end
    end
    
    ### Like a moron I used full urls in some posts. Pull those out and use relative ones.
    def change_self_ref_urls
      replace_with = '/words'
      re = /http:\/\/blog\.swilliams\.me\/words/
      @content.gsub! re, replace_with
    end

    ### Some images aren't displayed as images and use a client side library to display them. The image urls were stored in `data-src`, just swap that to a plain old `src` attribute.
    def fix_image_tags
      re = /data-src/
      @content.gsub! re, 'src'
    end

    ### Turns the downloaded post into a static html file. Downloads images, massages the post data, then writes it out locally.
    def export
      download_attachments
      change_self_ref_urls
      fix_image_tags
      @content = strip_html
      to_path = "#{Exporter.post_path}/#{published_date}-#{@filename}"
      File.open(to_path, 'w') { |f| f.write generate }
    end

    ### Date formatter for the published date.
    def published_date
      t = Time.at(@published / 1000)
      t.strftime "%Y-%m-%d"
    end

    ### Removes unnecessary styles and markdown from posts.
    def strip_html
      stripper = HtmlStripper.new @content
      stripper.strip
    end

    ### Creates the content for the static file.
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

  ### Uses Nokogiri to strip out unnecessary attributes and elements from a post.
  class HtmlStripper
    
    ### Constructor.
    def initialize(html_text)
      @doc = Nokogiri::HTML(html_text)
    end

    ### Walks each node and calls the appropriate method to scrub it.
    def strip
      @doc.traverse do |node|
        method_name = "handle_#{node.name}"
        send method_name, node if respond_to? method_name
      end
      @doc.css('body').inner_html
    end

    ### Don't need any extra attributes on divs.
    def handle_div(node)
      node.attributes.each do |key, value|
        node.attributes[key].remove
      end
    end

    ### Only need a few important attributes on imgs. Strip the others.
    def handle_img(node)
      whitelist = %w(src alt width height)
      node.attributes.each do |key, value|
        node.attributes[key].remove unless whitelist.include? key
      end
    end

    ### Don't need extra attributes on span.
    def handle_span(node)
      node.attributes.each do |key, value|
        node.attributes[key].remove
      end
    end

    ### What is this, 1999? If you don't have JavaScript enabled, GTFO.
    def handle_noscript(node)
      node.remove
    end
  end
end
