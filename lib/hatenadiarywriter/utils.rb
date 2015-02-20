# coding: utf-8
require 'io/console'
require 'uri'
require 'open3'
require 'levenshtein'


class HatenaDiaryWriter
  module Utils
    module_function

    def read_input(prompt, echo_back = true)
      return nil unless $stdin.tty?
      func = ->(f){
        $stderr.print prompt
        f.gets
      }
      if line = echo_back ? func[$stdin] : $stdin.noecho(&func)
        nl_trimmed = line.chomp!
        $stderr.puts unless echo_back && nl_trimmed
        line
      end
    end

    def parse_proxy_url(src)
      uri = URI.parse(src)
      uri = URI.parse("http://#{src}") if !uri.scheme || uri.instance_of?(URI::Generic)
      uri.normalize!
      case uri.scheme
      when "http", "https"
        ["#{uri.scheme}://#{uri.host}", uri.port]
      else
        raise ArgumentError, "invalid proxy URL: #{src}"
      end
    end

    def guess_similar_one(src, nominates, threshold_coefficient: 3)
      maybe, score = nominates.map{|nom| [nom, Levenshtein.distance(nom, src)] }.sort_by(&:last).first
      # src が短すぎる場合、 score(=編集距離)も自然と低く出るので、閾値は src の長さに緩やかに比例させる
      if maybe && score <= (src.length / threshold_coefficient)
        maybe
      end
    end

    def change_file_content(path)
      catch {|tag|
        File.open(path, 'r+'){|f|
          f.flock File::LOCK_EX
          changed_content = yield(f, ->(){ throw tag })
          f.rewind
          f.write changed_content
          f.truncate f.tell
        }
      }
    end

    def open_with_command_filter(path, command, encoding = Encoding.default_external)
      error = nil
      Open3.popen3(command){|inn, out, err, th|
        out.set_encoding encoding
        err.set_encoding encoding
        inn.write File.read(path, encoding: encoding)
        inn.close
        yield(out)
        th.join
        error = err.read
      }
      error.strip!
      error.empty? ? nil : error
    end
  end
end
