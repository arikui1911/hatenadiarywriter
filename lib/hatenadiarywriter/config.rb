require 'yaml'

class HatenaDiaryWriter
  CONFIG_DEFAULTS = {
    username:        nil,
    groupname:       nil,
    password:        nil,
    cookie_file:     nil,
    http_proxy:      nil,
    client_encoding: Encoding::UTF_8,
    server_encoding: Encoding::UTF_8,
    filter_command:  nil,
    diary_dir:       ".",
    diary_glob:      "*.txt",
    touch_file:      "touch.txt",
  }

  Config = Struct.new(*CONFIG_DEFAULTS.keys){
    # -> Array<String>
    def self.item_name_list
      ITEM_NAME_LIST
    end

    def initialize
      super
      CONFIG_DEFAULTS.each{|k, v| self[k] = v }
    end

    KEYMAPS = {
      'id'     => :username,
      'g'      => :groupname,
      'cookie' => :cookie_file,
      'filter' => :filter_command,
      'touch'  => :touch_file,
    }

    ITEM_NAME_LIST = CONFIG_DEFAULTS.keys.map(&:id2name) + KEYMAPS.keys

    def load(path, &if_invalid)
      load_yaml(path).each do |k, v|
        begin
          self[KEYMAPS[k] || k] = v
        rescue NameError
          raise unless block_given?
          yield(k)
        end
      end
      self
    end

    private

    def load_yaml(path)
      data = begin
               YAML.load(File.read(path), path)
             rescue Errno::ENOENT
               return
             end
      data = Hash.try_convert(data) or return
      data
    end
  }
end
