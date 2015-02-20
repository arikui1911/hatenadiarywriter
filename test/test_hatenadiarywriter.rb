require 'test-unit'
require 'flexmock'
require 'hatenadiarywriter'
require 'hatenadiarywriter/version'
require 'tmpdir'

module WithTestFilepath
  def with_test_filepath
    file = "#{Time.now.to_i}.txt"
    Dir.mktmpdir {|dir|
      yield File.join(dir, file)
    }
  end
end

class TestHatenaDiaryWriter < Test::Unit::TestCase
  test "version" do
    assert /\A\d\.\d\.\d\Z/ =~ HatenaDiaryWriter.version
  end
end

class TestHatenaDiaryWriterOption < Test::Unit::TestCase
  setup do
    @option = HatenaDiaryWriter::Option.new
  end

  data do
    set = {
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
    set.each{|k, v| set[k] = [k, v] }
    set
  end
  test "initial value" do |data|
    key, expected = data
    assert_equal expected, @option[key]
  end

  data do
    set = {
      debug:       ["--debug",            true],
      trivial:     ["--trivial",          true],
      username:    ["--username=NAME",    "NAME"],
      password:    ["--password=PASS",     "PASS"],
      user_agent:  ["--user-agent=iPhone", "iPhone"],
      timeout:     ["--timeout=666",       666],
      groupname:   ["--groupname=GROUP",   "GROUP"],
      cookie:      ["--cookie",            true],
      file:        ["--file=FILE",         "FILE"],
      timestamp:   ["--no-timestamp",      false],
      config_file: ["--config-file=CONF",  "CONF"],
    }
    set.each{|k, v| set[k] = [k, *v] }
    set
  end
  test "long options" do |data|
    key, opt, expected = data
    @option.parse([opt])
    assert_equal expected, @option[key]
  end

  data do
    set = {
      debug:       ["-d",       true],
      trivial:     ["-t",       true],
      username:    ["-uNAME",   "NAME"],
      password:    ["-pPASS",   "PASS"],
      user_agent:  ["-aiPhone", "iPhone"],
      timeout:     ["-T666",    666],
      groupname:   ["-gGROUP",  "GROUP"],
      cookie:      ["-c",       true],
      file:        ["-fFILE",   "FILE"],
      timestamp:   ["-M",       false],
      config_file: ["-nCONF",   "CONF"],
    }
    set.each{|k, v| set[k] = [k, *v] }
    set
  end
  test "short options" do |data|
    key, opt, expected = data
    @option.parse([opt])
    assert_equal expected, @option[key]
  end
end

class TestHatenaDiaryWriterConfig < Test::Unit::TestCase
  include WithTestFilepath

  setup do
    @config = HatenaDiaryWriter::Config.new
  end

  data do
    set = {
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
    set.each{|k, v| set[k] = [k, v] }
    set
  end
  test "initial_values" do |data|
    item, expected = data
    assert_equal expected, @config[item]
  end

  sub_test_case "#load" do
    data do
      set = {
        username:        100,
        groupname:       200,
        password:        300,
        cookie_file:     400,
        http_proxy:      500,
        client_encoding: 600,
        server_encoding: 700,
        filter_command:  800,
        diary_dir:       900,
        diary_glob:      123,
        touch_file:      456,
      }
      set.each{|k, v| set[k] = [k, v] }
      set
    end
    test "load values" do |data|
      src = <<-EOS
username:        100
groupname:       200
password:        300
cookie_file:     400
http_proxy:      500
client_encoding: 600
server_encoding: 700
filter_command:  800
diary_dir:       900
diary_glob:      123
touch_file:      456
      EOS

      with_test_filepath {|path|
        File.write path, src
        @config.load(path)
      }
      item, expected = data
      assert_equal expected, @config[item]
    end

    data(id:     [:username, 100],
         g:      [:groupname, 200],
         cookie: [:cookie_file, 300],
         proxy:  [:http_proxy, 400],
         filter: [:filter_command, 500],
         touch:  [:touch_file, 600])
    test "aliased names" do |data|
      src = <<-EOS
id:     100
g:      200
cookie: 300
proxy:  400
filter: 500
touch:  600
      EOS

      with_test_filepath {|path|
        File.write path, src
        @config.load(path)
      }
      item, expected = data
      assert_equal expected, @config[item]
    end

    test "handle invalid item by block" do
      src = <<-EOS
id:        user
groupname: group
hoge:      HOGEEEEEEEEE
cookie:    cookie.txt
proxy:     http://example.com:80
piyo:      666
    EOS
      expected = %w[hoge piyo]

      actual = []
      with_test_filepath {|path|
        File.write path, src
        @config.load(path){|invalid| actual << invalid }
      }
      assert_equal expected, actual
    end

    test "invalid item" do
      src = <<-EOS
id:        user
groupname: group
hoge:      HOGEEEEEEEEE
    EOS

      with_test_filepath {|path|
        File.write path, src
        e = assert_raise(NameError){ @config.load(path) }
        assert_equal 'hoge', e.name
      }
    end
  end
end

class TestHatenaDiaryWriterUtils < Test::Unit::TestCase
  include FlexMock::TestCase
  include WithTestFilepath

  setup do
    @m = HatenaDiaryWriter::Utils
  end

  sub_test_case "read_input" do
    test "ordinary case" do
      flexmock(:safe, $stdin){|mi|
        mi.should_receive(:tty?).and_return(true)
        mi.should_receive(:gets).and_return("readed text.\n")
        flexmock(:safe, $stderr){|me|
          me.should_receive(:print).with("prompt: ")
          assert_equal "readed text.", @m.read_input("prompt: ")
        }
      }
    end

    test "no newline in input" do
      flexmock(:safe, $stdin){|mi|
        mi.should_receive(:tty?).and_return(true)
        mi.should_receive(:gets).and_return("readed text.")
        flexmock(:safe, $stderr){|me|
          me.should_receive(:print).with("prompt: ")
          me.should_receive(:puts).with()
          assert_equal "readed text.", @m.read_input("prompt: ")
        }
      }
    end

    test "noecho" do
      flexmock(:safe, $stdin){|mi|
        mi.should_receive(:tty?).and_return(true)
        mi.should_receive(:noecho).and_yield($stdin)
        mi.should_receive(:gets).and_return("readed text.\n")
        flexmock(:safe, $stderr){|me|
          me.should_receive(:print).with("prompt: ")
          me.should_receive(:puts).with()
          assert_equal "readed text.", @m.read_input("prompt: ", false)
        }
      }
    end

    test "no tty" do
      flexmock(:safe, $stdin){|mock|
        mock.should_receive(:tty?).and_return(false)
        assert_equal nil, @m.read_input("prompt: ")
      }
    end
  end

  sub_test_case "parse_proxy_url()" do
     test "parse host and port" do
      assert_equal ["http://example.com", 8080], @m.parse_proxy_url("http://example.com:8080")
    end

    test "without scheme" do
      assert_equal ["http://example.com", 8080], @m.parse_proxy_url("example.com:8080")
    end

    test "only host" do
      assert_equal ["http://example.com", 80], @m.parse_proxy_url("example.com")
    end

    test "invalid scheme" do
      assert_raise ArgumentError do
        @m.parse_proxy_url("ftp://example.com:1234")
      end
    end
  end

  sub_test_case "guess_similar_one()" do
    test "get correct one" do
      assert_equal "Ruby", @m.guess_similar_one("Tuby", %w[Perl Python Ruby Java Lisp])
    end

    test "too short" do
      assert_nil @m.guess_similar_one("C", %w[A B D R Q])
    end
  end

  test "change_file_content" do
    src = <<-EOS
Ruby
Perl
Java
Python
    EOS

    expected = <<-EOS
01 Ruby
02 Perl
03 Python
    EOS

    with_test_filepath {|path|
      File.write path, src
      @m.change_file_content(path){|f, aborter|
        f.reject{|line| line.chomp == "Java" }.map.with_index{|line, idx|
          sprintf "%02d %s", idx + 1, line
        }.join
      }
      assert_equal expected, File.read(path)
    }
  end

  test "open_with_command_filter" do
    src = <<-EOS
M4A1
M1911A1
G36C
    EOS

    expected = <<-EOS
001 M4A1
002 M1911A1
003 G36C
    EOS

    with_test_filepath {|path|
      File.write path, src
      actual = nil
      error = @m.open_with_command_filter(path, %Q`ruby -ne 'printf "%03d %s", ARGF.lineno, $_'`){|f|        # "
        actual = f.read
      }
      assert_equal expected, actual
      assert_nil error
    }
  end
end
