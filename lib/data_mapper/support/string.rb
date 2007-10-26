module DataMapper
  module Support
    module String
      
      # I set the constant on the String itself to avoid inheritance chain lookups.
      def self.included(base)
        base.const_set('EMPTY', ''.freeze)
      end
      
      def ensure_starts_with(part)
        [0,1] == part ? self : (part + self)
      end
  
      def ensure_ends_with(part)
        [-1,1] == part ? self : (self + part)
      end
  
      def ensure_wrapped_with(a, b = nil)
        ensure_starts_with(a).ensure_ends_with(b || a)
      end
      
      # Matches any whitespace (including newline) and replaces with a single space
      # EXAMPLE:
      #   <<QUERY.compress_lines
      #     SELECT name
      #     FROM users
      #   QUERY
      #   => "SELECT name FROM users"
      def compress_lines(spaced = true)
        split($/).map { |line| line.strip }.join(spaced ? ' ' : '')
      end
      
      def margin(indicator = nil)
        target = dup
        lines = target.split($/)
        
        if indicator.nil?
          min_margin = nil
          lines.each do |line|
            if line =~ /(\s+)/ && (min_margin.nil? || $1.size < min_margin)
              min_margin = $1.size
            end
          end

          lines.map do |line|
            line.sub(/^\s{#{min_margin}}/, '')
          end.join($/)
        else
          lines.map do |line|
            line.sub(/^.*?#{"\\" + indicator}/, '')
          end.join($/)
        end
      end
      
    end # module String
  end # module Support
end # module DataMapper

class String #:nodoc:
  include DataMapper::Support::String  
end