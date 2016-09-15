module OpenRoadMachine
  class Util
    def self.clip_key(clip)
      File.basename(clip, '.MP4')
    end
  end
end
