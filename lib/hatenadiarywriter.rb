require 'hatenadiary'
require 'io/console'
require 'stringio'
require 'open3'
require 'fileutils'
require 'yaml'
require 'logger'
require 'optparse'
require 'levenshtein'


# Encoding.default_external = Encoding::UTF_8

class HatenaDiaryWriter
  def initialize
    @log = Logger.new($stderr)
    @log.level = Logger::INFO
    @option = Option.new
    @config = Config.new
  end

  def run
    list = diary_list()
    if list.empty?
      @log.info "No files are posted."
      return
    end
    using_username, using_password = decide_using_account()
    current_cookie_file = cookie_file_path()
    begin
      HatenaDiary.login(using_username, using_password,
                        groupname:        groupname,
                        read_timeout_sec: @option.timeout,
                        user_agent_alias: @option.user_agent,
                        cookie_file_path: current_cookie_file,
                        hatena_encoding:  @config.server_encoding){|client|
        list.each do |path, y, m, d|
          replace_timestamp(path) if @option.timestamp
          title, content = parse_diary(path)
          if delete_declared?(title)
            delete y, m, d
          else
            post y, m, d, title, content
          end
          sleep 1
        end
      }
    rescue HatenaDiary::LoginError
      if current_cookie_file
        @log.info "might be old cookie: #{current_cookie_file}: retry login."
        current_cookie_file = nil
        retry
      else
        raise
      end
    end
    FileUtils.touch touch_file unless @option.file
  end

  def parse_option(argv)
    parser = OptionParser.new
    @log.progname = parser.program_name
    on_options parser
    parser.parse! argv
  end

  MAYBE_THRESHOLD_COEFFICIENT = 3

  def load_config
    @config.load File.expand_path(@option.config_file)
  rescue InvalidConfigNamesError => e
    e.names.each do |name|
      maybe, score = Config.item_name_list.
        map{|nom| [nom, Levenshtein.distance(nom, name)] }.
        sort_by{|(_, d)| d }.first
      # name が短すぎる場合、 score(=編集距離)も自然と低く出るので、閾値は name の長さに
      # 緩やかに比例させる
      if maybe && score < (name.length / MAYBE_THRESHOLD_COEFFICIENT)
        @log.error "#{@option.config_file}: invalid config - `#{name}', maybe `#{maybe}' ?"
      else
        @log.error "#{@option.config_file}: invalid config - `#{name}'"
      end
    end
    raise e
  end

  private

  def decide_using_account
    using_username, using_password = username(), password()
    raise "missing username" unless using_username
    raise "missing password" unless using_password
  end

  def post(y, m, d, title, content)
    @log.info "Posting #{y}-#{m}-#{d}..."
    client.post y, m, d, title, content, trivial: @option.trivial
    @log.info "Post #{y}-#{m}-#{d}."
  end

  def delete(y, m, d)
    @log.info "Deleting #{y}-#{m}-#{d}..."
    client.delete y, m, d
    @log.info "Delete #{y}-#{m}-#{d}."
  end

  def username
    @option.username or @config.username or read_input("Username: ")
  end

  def password
    @option.password or @config.password or read_input("Password: ", true)
  end

  def groupname
    @option.groupname or @config.groupname
  end

  def read_input(prompt, noecho = false)
    return nil unless $stdin.tty?
    func = ->(f){
      $stderr.print prompt
      f.gets
    }
    if line = noecho ? $stdin.noecho(&func) : func[$stdin]
      no_nl = not(line.chomp!)
      $stderr.puts if noecho || no_nl
      line
    end
  end

  def http_proxy
    return nil if @config.http_proxy
    uri = URI.parse(@config.http_proxy)
    uri = URI.parse("http://#{@config.http_proxy}") unless uri.scheme
    case uri.scheme
    when "http", "https"
      ["#{uri.scheme}://#{uri.host}", uri.port]
    else
      raise ArgumentError, "invalid proxy URL: #{@config.http_proxy}"
    end
  end

  def cookie_file_path
    @option.cookie ? @config.cookie_file : nil
  end

  def delete_declared?(title)
    title.chomp == 'delete'
  end

  def diary_list
    if @option.file
      @log.debug "option -f: #{@option.file}"
      return [@option.file]
    end
    Dir.glob(diary_glob_pattern).map{|path|
      if (File.file?(path) && newer?(path) &&
          (m = File.basename(path, '.*').match(/\b(\d{4})-(\d{2})-(\d{2})\Z/)))
        @log.debug "files: #{path}"
        [path, *m.captures]
      end
    }.compact
  end

  def diary_glob_pattern
    File.join(File.expand_path(@config.diary_dir), @config.diary_glob)
  end

  def newer?(path)
    newer_than_touch_file_terms.call(File.mtime(path))
  end

  def newer_than_touch_file_terms
    @newer_than_touch_file_terms ||= begin
                                       criterion = File.mtime(touch_file)
                                       ->(t){ t > criterion }
                                     rescue Errno::ENOENT
                                       ->(t){ true }
                                     end
  end

  def touch_file
    File.expand_path(@config.touch_file)
  end

  def replace_timestamp(path)
    dirty = false
    src = File.foreach(path).map{|line|
      if line.start_with?('*t*')
        dirty = true
        "*#{Time.now.to_i}*#{line[3..-1]}"
      else
        line
      end
    }
    return unless dirty
    FileUtils.cp(path, "#{path}~")
    File.write(path, src.join)
  end

  def parse_diary(path)
    title = body = nil
    open_diary(path){|f|
      title = f.gets.tap{|line| break line.chomp if line }
      body = f.read
    }
    return title, body
  end

  def open_diary(path, &block)
    if @configs.filter_command
      error = nil
      Open3.popen3(@config.filter_command){|inn, out, err, th|
        out.set_encoding @config.client_encoding
        err.set_encoding @config.client_encoding
        inn.write File.read(path, encoding: @config.client_encoding)
        inn.close
        yield(out)
        th.join
        error = err.read
      }
      @log.error "filter: error occured: #{@config.filter_command}:\n#{error}" unless error.strip.empty?
    else
      File.open(path, external_encoding: @config.client_encoding, &block)
    end
  end

  class InvalidConfigNamesError < RuntimeError
    def initialize(names, msg)
      super msg
      @names = names.freeze
    end

    attr_reader :names
  end

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

    def load(path)
      data = begin
               YAML.load(File.read(path), path)
             rescue Errno::ENOENT
               return
             end
      data = Hash.try_convert(data) or return
      # picks undefined config item names
      invalids = data.each_key.select{|k|
        begin
          k = KEYMAPS[k] || k
          self[k] = data[k]
          false
        rescue NameError
          true
        end
      }
      raise InvalidConfigNamesError.new(invalids, "No such config item") unless invalids.empty?
    end
  }

  OPTION_DEFAULTS = {
    debug:       false,
    trivial:     false,
    username:    nil,
    password:    nil,
    user_agent:  nil,
    timeout:     nil,
    groupname:   nil,
    cookie:      false,
    file:        nil,
    timestamp:   true,
    config_file: "config.yml",
  }

  Option = Struct.new(*OPTION_DEFAULTS.keys){
    def initialize
      super
      OPTION_DEFAULTS.each{|k, v| self[k] = v }
    end
  }

  def on_options(o)
    o.on '-d', '--debug', "Turn on debug mode." do
      @log.level = Logger::DEBUG
      @log.debug "Debug on."
    end
    o.on '-t', '--trivial', "Turn on `Trivial update' mode." do
      @option.trivial = true
      @log.debug "Trivial on."
    end
    o.on '-u', '--username=ID', "Specify Hatena ID." do |id|
      @option.username = id
    end
    o.on '-p', '--password=PASS', "Specify a password." do |pass|
      @option.password = pass
    end
    o.on '-a', '--user-agent=NAME', "Specify user agent name to access." do |name|
      @option.user_agent = name
    end
    o.on '-T', '--timeout=SEC', "Specify timeout limit seconds.", Integer do |sec|
      @option.timeout = sec
    end
    o.on '-g', '--groupname=NAME', "Specify group name to post to group-diary." do |name|
      @option.groupname = name
    end
    o.on '-c', '--cookie', "Use cookie to access with config value `cookie_file'." do
      @option.cookie = true
    end
    o.on '-f', '--file=PATH', "Specify posting file." do |path|
      @option.file = path
    end
    o.on '-M', '--no-timestamp', "Suppress substituting *t* notation." do
      @option.timestamp = false
    end
    o.on '-n', '--config-file=PATH', "Specify a config file." do |path|
      @option.config_file = path
    end
  end
end
