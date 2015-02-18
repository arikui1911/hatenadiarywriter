require 'test/unit'
require 'hatenadiarywriter'
require 'hatenadiarywriter/version'

class TestHatenaDiaryWriter < Test::Unit::TestCase
  def test_version
    assert /\A\d\.\d\.\d\Z/ =~ HatenaDiaryWriter.version
  end
end

class TestHatenaDiaryWriterUtils < Test::Unit::TestCase
  def setup
    @m = HatenaDiaryWriter::Utils
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
    assert_equal nil, @m.guess_similar_one("C", %w[A B D R Q])
  end
end
