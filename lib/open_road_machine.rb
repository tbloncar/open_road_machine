$LOAD_PATH.unshift(File.dirname(__FILE__))

require 'dotenv'
Dotenv.load

require 'open_road_machine/runner'

module OpenRoadMachine
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure(&block)
      block.call(config)
    end
  end

  class Configuration
    attr_accessor :clip_directory, :screenshot_directory, :animation_directory

    def initialize
      @clip_directory = './clips'
      @screenshot_directory = './screenshots'
      @animation_directory = './animations'
    end
  end
end
