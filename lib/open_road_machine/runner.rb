require 'open_road_machine/util'
require 'open_road_machine/broadcast'

require 'pstore'
require 'twitter'
require 'image_optim'

module OpenRoadMachine
  class Runner
    class << self
      def run!
        init!

        puts "Processing #{new_dashcam_clips.count} new dashcam clip(s).\n"

        new_dashcam_clips.each do |clip_path|
          Broadcast.new(clip_path, @twitter, @img_optimizer).process_and_broadcast! do
            @data.transaction do
              key = Util.clip_key(clip_path)

              @data['checkpoints'][key] = {}
              puts "Processed clip: #{key}"
            end
          end

          # Guard against rate-limiting with random delay
          sleep(2 + rand(5))
        end
      end

      private

      def init!
        @data ||= PStore.new(File.expand_path("#{File.dirname(__FILE__)}/../..") + '/data.pstore')
        @data.transaction do
          @data['checkpoints'] ||= {}
        end

        @twitter ||= Twitter::REST::Client.new do |config|
          config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
          config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
          config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
          config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
        end

        @img_optimizer = ImageOptim.new(allow_lossy: true,
                                        pngcrush: false,
                                        pngout: false,
                                        advpng: false,
                                        optipng: false,
                                        pngquant: false,
                                        jhead: false,
                                        svgo: false)
      end

      def new_dashcam_clips
        @data.transaction do
          Dir["#{OpenRoadMachine.config.clip_directory}/*.MP4"].reject { |clip| @data['checkpoints'][Util.clip_key(clip)] }
        end
      end
    end
  end
end
