require 'io/console'
require 'uri'
require 'levenshtein'
require 'open3'

class HatenaDiaryWriter
  module Utils
    module_function def read_input(prompt, noecho = false)
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

    module_function def parse_proxy_url(src)
      uri = URI.parse(src)
      uri = URI.parse("http://#{src}") unless uri.scheme
      case uri.scheme
      when "http", "https"
        ["#{uri.scheme}://#{uri.host}", uri.port]
      else
        raise ArgumentError, "invalid proxy URL: #{src}"
      end
    end

    module_function def guess_similar_one(src, nominates, threshold_coefficient: 3)
      maybe, score = nominates.map{|nom| [nom, Levenshtein.distance(nom, src)] }.sory_by(&:last).first
      # src が短すぎる場合、 score(=編集距離)も自然と低く出るので、閾値は src の長さに緩やかに比例させる
      if maybe && score < (src.length / threshold_coefficient)
        maybe
      end
    end

    module_function def open_with_command_filter(path, command, encoding = Encoding.default_external)
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
