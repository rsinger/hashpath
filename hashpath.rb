require 'strscan'
class Hash
  def path(path)
    scanner = StringScanner.new path
    matches = [self]
    if path =~ /^\/\//
      # TODO
    else
      unless scanner.getch == "/"
        scanner.reset
      end
      until scanner.eos?
        matches = fetch_path_matches(scanner, matches)
      end
    end  
    matches
  end
  
  def fetch_path_matches(scanner, matched_paths)
    in_subquery = false
    path = ''
    subquery = ''
    escaped = false
    while char = scanner.getch
      if char == "\\" && !escaped
        escaped = true
        next
      end
      if char == "/" && (!in_subquery || !escaped)
        break
      end
      if char == "[" && !escaped
        in_subquery = true
      end
      if char == "]" && !escaped
        in_subquery = false
      end
      if in_subquery
        subquery << char
      else
        path << char
      end
      escaped = false
    end
    path = translate_path(path)
    matches = []
    matched_paths.each do |match|
      if path == '*'
        if match.is_a?(Hash)
          match.each_key do |key|
            matches << match[key]
          end
        elsif match.is_a?(Array)
          match.each_index do |idx|
            matches << match[idx]
          end
        end
      elsif match[path]
        matches << match[path]
      end
      unless subquery.empty? || matches.empty?
        matches = fetch_subquery_matches(subquery, matches)
      end
    end
    matches  
  end
  
  def fetch_subquery_matches(subquery, matches)
    scan = StringScanner.new(subquery)
    subqueries = []
    path = ''
    subquery = ''
    escaped = false
    while char = scan.getch
      if char == "\\" && !escaped
        escaped = true
        next
      end
      if char == "/" && (subqueries.empty? || !escaped)
        break
      end
      if char == "[" && !escaped
        subqueries << true
        next if subqueries.length == 1          
      end
      if char == "]" && !escaped
        subqueries.pop
        next if subqueries.empty?
      end
      if in_subquery
        subquery << char
      else
        path << char
      end
      escaped = false
    end    
  end
  
  def translate_path(path)
    if path =~ /^:\w/
      path = path.sub(/^:/).to_sym
    elsif path =~ /^:\d*\.\d/
      path = path.sub(/^:/).to_f
    elsif path =~ /^:\d/
      path = path.sub(/^:/).to_i
    end
    path
  end    
end
  