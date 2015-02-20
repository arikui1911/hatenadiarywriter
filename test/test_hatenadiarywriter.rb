require 'test/unit'
require 'flexmock/test_unit'
require 'hatenadiarywriter'
require 'hatenadiarywriter/version'
require 'tmpdir'

class TestHatenaDiaryWriter < Test::Unit::TestCase
  def test_version
    assert /\A\d\.\d\.\d\Z/ =~ HatenaDiaryWriter.version
  end
end

class TestHatenaDiaryWriterUtils < Test::Unit::TestCase
  def setup
    @m = HatenaDiaryWriter::Utils
  end

  def test_read_input
    flexmock(:safe, $stdin){|mi|
      mi.should_receive(:tty?).and_return(true)
      mi.should_receive(:gets).and_return("readed text.\n")
      flexmock(:safe, $stderr){|me|
        me.should_receive(:print).with("prompt: ")
        assert_equal "readed text.", @m.read_input("prompt: ")
      }
    }
  end

  def test_read_input_no_nl_in_input
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

  def test_read_input_noecho
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

  def test_read_input_no_tty
    flexmock(:safe, $stdin){|mock|
      mock.should_receive(:tty?).and_return(false)
      assert_equal nil, @m.read_input("prompt: ")
    }
  end

  def test_parse_proxy_url
    assert_equal ["http://example.com", 8080], @m.parse_proxy_url("http://example.com:8080")
  end

  def test_parse_proxy_url_without_scheme
    assert_equal ["http://example.com", 8080], @m.parse_proxy_url("example.com:8080")
  end

  def test_parse_proxy_url_only_host
    assert_equal ["http://example.com", 80], @m.parse_proxy_url("example.com")
  end

  def test_parse_proxy_url_invalid_scheme
    assert_raise ArgumentError do
      @m.parse_proxy_url("ftp://example.com:1234")
    end
  end

  def test_guess_similar_one
    assert_equal "Ruby", @m.guess_similar_one("ruby", %w[Perl Python Ruby Java Lisp])
  end

  def test_guess_similar_one_too_short
    assert_nil @m.guess_similar_one("C", %w[A B D R Q])
  end

  def with_test_filepath
    file = "#{Time.now.to_i}.txt"
    Dir.mktmpdir {|dir|
      yield File.join(dir, file)
    }
  end

  def test_change_file_content
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

  def test_open_with_command_filter
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
