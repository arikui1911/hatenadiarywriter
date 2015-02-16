require 'optparse'

class HatenaDiaryWriter
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
  private_constant :OPTION_DEFAULTS

  Option = Struct.new(*OPTION_DEFAULTS.keys){
    private def on_options(o)
      o.on '-d', '--debug', "Turn on debug mode." do
        self.debug = true
      end
      o.on '-t', '--trivial', "Turn on `Trivial update' mode." do
        self.trivial = true
      end
      o.on '-u', '--username=ID', "Specify Hatena ID." do |id|
        self.username = id
      end
      o.on '-p', '--password=PASS', "Specify a password." do |pass|
        self.password = pass
      end
      o.on '-a', '--user-agent=NAME', "Specify user agent name to access." do |name|
        self.user_agent = name
      end
      o.on '-T', '--timeout=SEC', "Specify timeout limit seconds.", Integer do |sec|
        self.timeout = sec
      end
      o.on '-g', '--groupname=NAME', "Specify group name to post to group-diary." do |name|
        self.groupname = name
      end
      o.on '-c', '--cookie', "Use cookie to access with config value `cookie_file'." do
        self.cookie = true
      end
      o.on '-f', '--file=PATH', "Specify posting file." do |path|
        self.file = path
      end
      o.on '-M', '--no-timestamp', "Suppress substituting *t* notation." do
        self.timestamp = false
      end
      o.on '-n', '--config-file=PATH', "Specify a config file." do |path|
        self.config_file = path
      end
    end

    def initialize(program_name = nil)
      super
      OPTION_DEFAULTS.each{|k, v| self[k] = v }
      @parser = OptionParser.new
      @parser.program_name = program_name if program_name
      on_options @parser
    end

    def program_name
      @parser.program_name
    end

    def parse(argv)
      @parser.parse(argv)
    end
  }
end
