module DataMapper
  module Support
    module String
      
      def ensure_starts_with(part)
        [0,1] == part ? self : (part + self)
      end
  
      def ensure_ends_with(part)
        [-1,1] == part ? self : (self + part)
      end
  
      def ensure_wrapped_with(a, b = nil)
        ensure_starts_with(a).ensure_ends_with(b || a)
      end
      
    end # module String
  end # module Support
end # module DataMapper

class String
  include DataMapper::Support::String
end