#!/usr/bin/env ruby

require 'rexml/document'
require 'date'
require 'rubygems'
require 'rdiscount'
require 'ftools'

if ARGV.empty?
    puts "Usage: parser.rb <your name for the introduction> <the exported wordpress XML filename> [<the filename to output to>]"
    puts "Make sure there's a file called introduction.txt in this directory, which will be the introduction of your book"
    exit
end

author_name = ARGV[0]
filename = ARGV[1] || "wordpress.xml"
html_filename = ARGV[2] || "index.html"
introduction_filename = "introduction.txt"

if not author_name
    puts "Please specify your name for the introduction"
    exit
end

if not File.exist?(filename)
    puts "#{filename} does not exist"
    exit
end

if not File.exist?(introduction_filename)
    puts "Introduction file #{introduction_filename} does not exist"
    exit
end

# create the target directory if it doesn't already exist
File.makedirs("target/book")

word_counts_by_author = {}
num_posts_by_author = {}

class Post
    attr_reader :title, :author, :content, :post_date, :post_name

    def initialize(type, status, post_name, title, author, content, post_date)
        @type = type
        @status = status
        @post_name = post_name
        @title = title
        @author = author
        @content = content
        @post_date = post_date
    end

    def self.parse(item)
        type = nil
        item.elements.each('wp:post_type') { |type_elem|
            type = type_elem.text
        }
        status = nil
        item.elements.each('wp:status') { |status_elem|
            status = status_elem.text
        }
        post_name = nil
        item.elements.each('wp:post_name') { |post_name_elem|
            post_name = post_name_elem.text
        }
        title = nil
        item.elements.each('title'){ |title_elem|
            title = title_elem.text
        }
        author = nil
        item.elements.each('dc:creator'){ |creator_elem|
            author = creator_elem.text
        }
        content = nil
        item.elements.each('content:encoded'){ |content_elem|
            content = content_elem.text
        }
        post_date = nil
        item.elements.each('wp:post_date'){ |post_date_elem|
            post_date = DateTime.parse(post_date_elem.text)
        }

        Post.new(type, status, post_name, title, author, content, post_date)
    end

    def post?
        @type == "post"
    end

    def published?
        @status == "publish"
    end

    def num_words
        @content.split.length
    end

    def html
        "<div class=\"post\"><h2 class=\"title\"><a name=\"#{@post_name}\">#{@title}</a></h2><h3 class=\"author\">#{@author}</h3><h4 class=\"date\">#{@post_date.strftime('%A, %B %d, %Y; %I:%M %p')}</h4><div class=\"post_content\">#{self.content_html}</div></div>"
    end

    def content_html
        markdown = RDiscount.new(@content)
        markdown.to_html
    end
end

total_html = <<eos
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"> 
<html xmlns="http://www.w3.org/1999/xhtml"> 
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /> 
<body>
eos

posts = []

introduction = Post.new('post', 'publish', 'introduction', 'Introduction', author_name, File.read(introduction_filename), DateTime.now)
posts << introduction

puts "Parsing #{filename}..."
doc = REXML::Document.new(File.read(filename))
doc.elements.each("//item"){ |item|
    post = Post.parse(item)
    if post.post? and post.published?
        if not num_posts_by_author.has_key?(post.author)
            num_posts_by_author[post.author] = 0
        end
        num_posts_by_author[post.author] += 1
        if not word_counts_by_author.has_key?(post.author)
            word_counts_by_author[post.author] = 0
        end
        word_counts_by_author[post.author] += post.num_words

        posts << post
    end
}

# build the table of contents
puts "Building table of contents..."
total_html += "<h1>Table of Contents</h1>"
posts.each{ |post|
    total_html += "<p><a href=\"index.html##{post.post_name}\">#{post.title}</a></p>"
}

# add all the posts to the html
puts "Adding posts to HTML..."
posts.each{ |post|
    total_html += post.html
}

total_html += "</body></html>"

puts "Writing #{html_filename}..."
File.open(html_filename, 'w'){ |file| file.write(total_html) }

puts "\nNum posts:"
num_posts_by_author.each{ |author, num_posts|
    puts "#{author}: #{num_posts}"
}

puts "\nTotal words:"
word_counts_by_author.keys.each{ |author|
    puts "#{author}: #{word_counts_by_author[author]}"
}

puts "\nDone"
