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
    (path, subquery) = parse_path(scanner)
    path = translate_path(path) if path
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
      elsif path && match[path]
        matches << match[path]
      end
      if subquery && !matches.empty?
        matches = fetch_subquery_matches(subquery, Hash[matches.map{|m| [m, [m]]}])
      end
    end
    matches  
  end
  
  def parse_path(scanner)
    in_subquery = []
    path = ''
    subquery = ''
    escaped = false
    if scanner.peek(1) == "/"
      scanner.getch
    end
    while char = scanner.getch
      if char == "\\" && !escaped
        escaped = true
        next
      end
      if char == "/" && (in_subquery.empty? && !escaped)
        break
      end
      if char == "[" && !escaped
        in_subquery << true
        next if in_subquery.length == 1
      end
      if char == "]" && !escaped
        in_subquery.pop
        next if in_subquery.empty?
      end
      unless in_subquery.empty?
        subquery << char
      else
        path << char
      end
      escaped = false
    end   
    path = nil if path.empty?
    subquery = nil if subquery.empty?
    [path, subquery]    
  end
  
  def fetch_subquery_matches(subquery, matched_paths)    
    scan = StringScanner.new(subquery)
    (path, sub_subquery) = parse_path(scan)
    matches = {}
    comparison = path ? check_for_comparison(path) : nil
    matched_paths.each_pair do |base_match,subquery_matches|
      subquery_matches.each do |subquery_match|
        if path == '*'
          if comparison
            puts comparison.inspect
            match = []
            if subquery_match.is_a?(Hash)
              subquery_match.each_key do |key|
                if subquery_match[key].send(comparison[:operator].to_sym, comparison[:entity])
                  match << subquery_match[key]
                end
              end
            elsif subquery_match.is_a?(Array)
              subquery_match.each_index do |idx|
                if subquery_match[idx].send(comparison[:operator].to_sym, comparison[:entity])
                  match << subquery_match[idx]
                end
              end
            end 
            matches[base_match] = match unless match.empty?           
          else
            matches[base_match] ||= []
            if subquery_match.is_a?(Hash)
              subquery_match.each_key do |key|
                matches[base_match] << subquery_match[key]
              end
            elsif subquery_match.is_a?(Array)
              subquery_match.each_index do |idx|
                matches[base_match] << subquery_match[idx]
              end
            end
          end
        elsif path && subquery_match[path]
          matches[base_match] ||= []
          matches[base_match] << subquery_match[path]
        end
      end
      if sub_subquery && !matches.empty?
        matches = fetch_subquery_matches(sub_subquery, matches)
      end
    end 
    matches.keys   
  end
  
  def check_for_comparison(path)
    comparison = nil
    if match = path.match(/\s([<>=!]={0,2})\s(.*)/)
      comparison = {:operator=>match[1], :entity=>typecast(match[2])}      
    end
    comparison
  end
  
  def typecast(string)
    cast_object = case
    when string =~ /^(-?0|-?[1-9]\d*)$/ then string.to_i
    when string =~ /^true$/ then true
    when string =~ /^false$/ then false
    when string =~ /^:[\"\w]/ then string.sub(/^:\"?/, '').sub(/\"$/, '').to_sym
    when string =~ /^nil$/ then nil
    when string =~ /^\".*\"$/ then string.sub(/^\"/, '').sub(/\"$/, '')
    when string =~ /^\'.*\'$/ then string.sub(/^\'/, '').sub(/\'$/, '')
    when string =~   /^(-?(?:0|[1-9]\d*)(?:\.\d+(?i:e[+-]?\d+) | \.\d+ | (?i:e[+-]?\d+)))$/x then string.to_f
    end
  end
  
  def translate_path(path)
    if path =~ /^:[\"\w]/
      path = path.sub(/^:\"?/, '').sub(/\"$/, '').to_sym
    elsif path =~ /^:\d*\.\d/
      path = path.sub(/^:/, '').to_f
    elsif path =~ /^:\d/
      path = path.sub(/^:/, '').to_i
    end
    path
  end    
end
  