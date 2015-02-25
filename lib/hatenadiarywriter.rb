# coding: utf-8
require 'hatenadiarywriter/option'
require 'hatenadiarywriter/config'
require 'hatenadiarywriter/utils'
require 'hatenadiary'
require 'logger'
require 'fileutils'

class HatenaDiaryWriter
  class Error < RuntimeError ; end

  include Utils

  def self.run(argv)
    new().run argv
  end

  def initialize
    @log = Logger.new($stderr)
    @log.level = Logger::INFO
    @option = Option.new
    @config = Config.new
    @log.progname = @option.program_name
    @log.formatter = method(:format_log)
  end

  def run(argv)
    parse_option argv
    load_config
    process_diaries
    FileUtils.touch touch_file unless @option.file
  rescue Error => ex
    raise if @option.debug
    @log.error ex.message
  end

  def parse_option(argv)
    @option.parse argv
    if @option.debug
      @log.level = Logger::DEBUG
      @log.debug "Debug on."
    end
    if @option.trivial
      @log.debug "Trivial on."
    end
  end

  def load_config
    dirty = false
    @config.load File.expand_path(@option.config_file) do |invalid|
      dirty = true
      maybe = guess_similar_one(invalid, Config.item_name_list)
      if maybe
        @log.error "#{@option.config_file}: invalid config - `#{invalid}', maybe `#{maybe}' ?"
      else
        @log.error "#{@option.config_file}: invalid config - `#{invalid}'"
      end
    end
    raise "no such config items" if dirty
  end

  private

  def format_log(severity, time, program_name, message)
    if severity == "INFO"
      "#{program_name}: #{message}\n"
    else
      "#{program_name}: #{severity}: #{message}\n"
    end
  end

  def process_diaries
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
                        http_proxy:       http_proxy(),
                        cookie_file_path: current_cookie_file,
                        hatena_encoding:  @config.server_encoding){|client|
        list.each do |path, y, m, d|
          replace_timestamp(path) if @option.timestamp
          title, content = parse_diary(path)
          if delete_declared?(title)
            delete client, y, m, d
          else
            post client, y, m, d, title, content
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
  end

  def decide_using_account
    using_username, using_password = username(), password()
    raise "missing username" unless using_username
    raise "missing password" unless using_password
    return using_username, using_password
  end

  def post(client, y, m, d, title, content)
    @log.info "Posting #{y}-#{m}-#{d}..."
    client.post y, m, d, title, content, trivial: @option.trivial
    @log.info "Post #{y}-#{m}-#{d}."
  end

  def delete(client, y, m, d)
    @log.info "Deleting #{y}-#{m}-#{d}..."
    client.delete y, m, d
    @log.info "Delete #{y}-#{m}-#{d}."
  end

  def username
    @option.username or @config.username or read_input("Username: ")
  end

  def password
    @option.password or @config.password or read_input("Password: ", false)
  end

  def groupname
    @option.groupname or @config.groupname
  end

  def http_proxy
    return nil unless @config.http_proxy
    parse_proxy_url @config.http_proxy
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
      if File.file?(path) && newer?(path)
        # path_to/yyyy-mm-dd.ext ( path_to は任意のパス、 ext は任意の拡張子) にマッチ
        if m = File.basename(path, '.*').match(/\b(\d{4})-(\d{2})-(\d{2})\Z/)
          @log.debug "files: #{path}"
          [path, *m.captures]
        end
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
    change_file_content(path){|f, aborter|
      dirty = false
      contents = f.map{|line|
        if line.start_with?('*t*')
          dirty = true
          "*#{Time.now.to_i}*#{line[3..-1]}"
        else
          line
        end
      }.join
      throw aborter.call unless dirty
      contents
    }
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
    if @config.filter_command
      err = open_with_command_filter(path, @config.filter_command, @config.client_encoding, &block)
      @log.error "filter: error occured: #{@config.filter_command}:\n#{err}" if err
    else
      File.open(path, external_encoding: @config.client_encoding, &block)
    end
  end
end
