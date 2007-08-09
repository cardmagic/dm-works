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
      def compress_lines
        gsub(/\s+/, ' ').strip
      end
      
    end # module String
  end # module Support
end # module DataMapper

class String #:nodoc:
  include DataMapper::Support::String
  
  def self.fragile_underscore(camel_cased_word)
    camel_cased_word.gsub(/([a-z\d])([A-Z])/,'\1_\2').downcase
  end
  
  @underscore_cache = Hash.new { |h,k| h[k.freeze] = fragile_underscore(k) }
  
  def self.memoized_underscore(camel_cased_word)
    @underscore_cache[camel_cased_word]
  end
  
end