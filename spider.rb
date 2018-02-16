require 'bundler/setup'
require 'capybara/dsl'
require 'capybara-webkit'
require 'headless'
require 'fileutils'

Capybara.current_driver = :webkit

include Capybara::DSL

Capybara::Webkit.configure do |config|
  config.debug = false
  config.allow_unknown_urls
  config.timeout = 60
  config.ignore_ssl_errors
  config.skip_image_loading
  config.raise_javascript_errors = true
end

headless = Headless.new
headless.start

key_question_links = []

catch(:done) do
  (1..18).each do |page_num|
    visit("http://2d.hep.cn/mobile/book/show/java577?page=#{page_num}")
    all('.weui_media_box .weui-cell__bd a').each do |key_question_link|
      next if key_question_link.text == "总目录"
      throw :done unless key_question_link.text.start_with?('教学关键问题')
      key_question_links << { text: key_question_link.text, url: key_question_link[:href] }
    end
  end
end

microclass_links = []

key_question_links.each do |key_question_link|
  visit(key_question_link[:url])
  all('.weui-weixin-content table a').each do |microclass|
    microclass_links << { text: microclass.text, url: microclass[:href], key_question: key_question_link[:text] }
  end
end

video_links = []

microclass_links.each do |microclass_link|
  visit(microclass_link[:url])
  all('.weui-weixin-content table a').each do |video_link|
    video_links << { text: video_link.text, url: video_link[:href], key_question: microclass_link[:key_question], microclass: microclass_link[:text] }
  end
end

video_links.each do |video_link|
  visit(video_link[:url])
  video_url = find('video source')[:src]
  dir = File.join(video_link[:key_question], video_link[:microclass])
  FileUtils.mkdir_p(dir)
  filepath = File.join(dir, "#{video_link[:text]}.mp4")
  unless File.exists?(filepath)
    system('ffmpeg', '-i', video_url, filepath) or raise "Failed"
  end
rescue => e
  STDERR.puts "Error: #{e.message}"
  retry
end

headless.destroy
