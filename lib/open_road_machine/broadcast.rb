require 'open_road_machine/util'

require 'streamio-ffmpeg'
require 'rtesseract'
require 'geocoder'

module OpenRoadMachine
  class Broadcast
    def initialize(clip_path, twitter, img_optimizer)
      @video = FFMPEG::Movie.new(clip_path)
      @key = Util.clip_key(clip_path)
      @twitter = twitter
      @img_optimizer = img_optimizer
    end

    def process_and_broadcast!(&block)
      @video.screenshot(screenshot_path, quality: 1)
      @screenshot_text = RTesseract.new(screenshot_path).to_s

      location = extract_screenshot_location
      speed = extract_screenshot_speed

      if location && speed
        # TODO: Support different artifact options
        generate_animation
        compose_and_send_tweet(location, speed)

        # Call callback block
        block.call
      end
    end

    private

    def generate_animation
      Dir.mktmpdir do |dir|
        # Screenshot animation frames
        @video.screenshot("#{dir}/frame_%d.jpg", { vframes: 4, frame_rate: '1/2' }, quality: 1, validate: false)

        frame_paths = Dir["#{dir}/frame_*.jpg"]

        # Optimize frames
        @img_optimizer.optimize_images!(frame_paths)

        # Extract animation frames
        frames = Magick::ImageList.new(*frame_paths)

        # Crop frames
        frames = frames.collect do |frame|
          frame.crop!(0,0,2560,1350)
          frame.delay = 50
          frame.adaptive_resize(0.7)
        end

        # Save animation
        frames.write(animation_path)

        # Optimize animation
        @img_optimizer.optimize_image!(animation_path)
      end
    end

    def compose_and_send_tweet(location, speed)
      upload = File.open(animation_path)
      upload_id = @twitter.upload(upload)

      @twitter.update("#{verb_clause(speed)} #{location}.", media_ids: upload_id.to_s)

      upload.close
    end

    def extract_screenshot_location
      location_match_data = @screenshot_text.match(/W(?<longitude>\d{2}[.\s-]{1,2}\d{5,6})\sN(?<latitude>\d{2}[.\s-]{1,2}\d{5,6})/)

      if location_match_data
        latitude = location_match_data[:latitude].gsub(' ', '').gsub('-', '.')
        longitude = location_match_data[:longitude].gsub(' ', '').gsub('-', '.')

        if locations = Geocoder.search("#{latitude},-#{longitude}")
          locale = locations.first
          location = "#{locale.city}, #{locale.state_code}" if locale
        end
      end

      location
    end

    def extract_screenshot_speed
      speed_match_data = @screenshot_text.match(/(?<speed>\d{1,3})km\/h/)
      speed_match_data ? speed_match_data[:speed].to_i : 0
    end

    STILL_PHRASES = ['🚘 Idling', '🕰 Killing time', '😴 Resting the engine'].freeze
    SLOW_PHRASES = ['Coasting', 'Gliding', 'Drifting', '☁️ Floating'].freeze
    FAST_PHRASES = ['🛴 Scooting', '🚗 Cruising', '🎡 Freewheelin\''].freeze
    SPEED_PHRASES = ['🤐 Zipping', '🏎 Making haste', '⚡ Bolting'].freeze

    def verb_clause(speed)
      if speed == 0
        "#{STILL_PHRASES.sample} in"
      elsif speed < 40
        "#{SLOW_PHRASES.sample} through"
      elsif speed < 80
        "#{FAST_PHRASES.sample} through"
      elsif speed >= 80
        "#{SPEED_PHRASES.sample} through"
      else
        'Driving through'
      end
    end

    def screenshot_path
      "#{OpenRoadMachine.config.screenshot_directory}/#{@key}.jpg"
    end

    def animation_path
      "#{OpenRoadMachine.config.animation_directory}/#{@key}.gif"
    end
  end
end
