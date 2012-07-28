# Orep --version 1.0
# Example:
# !ruby -S[-m <num>][-f][-e <pattern>] 'pattern' region

require 'find'
require 'date'


debug = false 

arr_in_path = Array.new
search_pattern = ""
search_filename_mode = nil
expand_pattern = ""
flag_first = true
is_flag_param = false
max_hit_num = 100000
to_patten = ""
offset_num = 0
file = nil
state = ""
from_date = nil

def d2time(date)
    Time.mktime(date.year, date.month, date.day)
end

begin 
  ARGV.each{|elem|
    if (elem[0].chr == '-')
      unless elem[1]
        raise "<Option flag is not set>"
      end

      state = elem[1].chr
      case state
      when 'm'
        is_flag_param = true
      when 'f'
        search_filename_mode = 1
      when 'F'
        search_filename_mode = 2
      when 'e'
        is_flag_param = true
      when 't'
        is_flag_param = true
      when 'o'
        is_flag_param = true
      when 'd'
        is_flag_param = true
      end
    else 
      unless is_flag_param
        if (flag_first)
          search_pattern = elem  
          flag_first = false
        else
          arr_in_path.push(elem)
        end
      else
        begin
          case state
          when 'm'
            max_hit_num = elem.to_i
          when 't'
            to_patten = elem
          when 'e'
            if elem[0].chr == '@'  
              format = elem[1..elem.length-1];
              if format.empty?
                raise "<Extention is empty>"
              end
              if format == "cpp"
                expand_pattern = "(\.h|.cpp)$"
              elsif format == "c"
                expand_pattern = "(\.h|\.c)$"
              elsif format == "rc"
                expand_pattern = "(\.rc|resource\.h)$"
              elsif format == "web"
                expand_pattern = "\.(jsp|html|inc|js|css)$"
              else
                expand_pattern = "\.#{format}$"
              end  
            else
              expand_pattern = elem
            end
          when 'o'
            offset_num = elem.to_i
          when 'd'
            from_date = d2time(Date.strptime(elem))
          end
        rescue => ex
          unless ex
            raise "<Option value is invalid>"
          end
          raise ex
        end
        is_flag_param = false
      end
      state = ""
    end
  }

  puts "ARGV: #{ARGV}" if debug
  unless to_patten.empty?
    puts "search_from: #{search_pattern}"
    puts "search_to  : #{to_patten}"
  else
    puts "search_pattern: #{search_pattern}"
  end

  if search_pattern.empty?
    raise "<No search pattern>"
    return 
  end

  if arr_in_path.empty?
    raise "<No search target>"
    return 
  end

  search_pattern = Regexp.new(search_pattern)
  unless expand_pattern.empty?
    expand_pattern = Regexp.new(expand_pattern)
  end
  unless to_patten.empty?
    to_patten = Regexp.new(to_patten)
  end

  hit_cnt = 0

  if search_filename_mode
    arr_in_path.each{|in_path|
      Find.find(in_path){|path|
        target_name = ""
        if !FileTest.directory?(path)
          base, target_name = File.split(path)
        elsif search_filename_mode == 2
          target_name = path.split(/\/|\\/).pop
        else 
          next
            end
        if from_date && (File.mtime(path) > from_date)
            next
        end
        if !expand_pattern.to_s.empty? && !(target_name =~ expand_pattern)
          next
        end
        if target_name =~ search_pattern
          puts path 
          hit_cnt += 1
          if hit_cnt > max_hit_num
            raise "<------------------------------>\n<Search result over #{max_hit_num} records>"
          end
        end
      }
    }
  else
    arr_in_path.each{|in_path|
      Find.find(in_path){|path|
        unless FileTest.directory?(path)
          if from_date && (File.mtime(path) > from_date)
            next
          end
          base, name = File.split(path)
          puts "base: #{path} name : #{base}" if debug
          if !expand_pattern.to_s.empty? && !(name =~ expand_pattern)
            next
          end
          file = File.new(path)
          is_first = true
          if !to_patten.to_s.empty?
            arr_hit_buf = Array.new
            is_on_range = false
            file.each{|line|
              if is_on_range
                arr_hit_buf.push "\t#{file.lineno}> #{line}"
                hit_cnt += 1
                if line =~ to_patten
                  if is_first
                    puts path
                  end
                  is_first = false

                  arr_hit_buf.each{|buf_line| puts buf_line}
                  arr_hit_buf = Array.new
                  is_on_range = false
                end
              elsif line =~ search_pattern
                is_on_range = true 
                if hit_cnt > max_hit_num
                  raise "<------------------------------>\n<Search result over #{max_hit_num} records>"
                end
                redo
              end
            }
          elsif offset_num > 0
            offset_cnt = 0
            file.each{|line|
              if offset_cnt > 0
                puts "\t#{file.lineno}> #{line}"
                offset_cnt -= 1
                hit_cnt += 1
                if hit_cnt > max_hit_num
                  raise "<------------------------------>\n<Search result over #{max_hit_num} records>"
                end
              elsif line =~ search_pattern
                if is_first
                  #puts "#{path}-->"
                  puts path
                end
                is_first = false
                puts "\t#{file.lineno}> #{line}"

                offset_cnt = offset_num
                hit_cnt += 1
                if hit_cnt > max_hit_num
                  raise "<------------------------------>\n<Search result over #{max_hit_num} records>"
                end
              end
            }
          else
            file.each{|line|
              if line =~ search_pattern
                if is_first
                  #puts "#{path}-->"
                  puts path
                end
                is_first = false
                puts "\t#{file.lineno}> #{line}"

                hit_cnt += 1
                if hit_cnt > max_hit_num
                  raise "<------------------------------>\n<Search result over #{max_hit_num} records>"
                end
              end
            }
          end
          file.close
        end
      }
    }
  end
rescue RegexpError
  puts "<Invalid regular expression>"
rescue
  puts $!  
ensure
  file.close unless file == nil || file.closed?
end
