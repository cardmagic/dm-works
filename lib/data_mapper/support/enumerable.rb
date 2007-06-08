module DataMapper
  module Support
    module Enumerable
  
      def group_by
        inject(Hash.new { |h,k| h[k] = [] }) do |memo,item|
          memo[yield(item)] << item; memo
        end
      end
  
    end # module Enumerable
  end # module Support
end # module DataMapper

class Array
  include DataMapper::Support::Enumerable
end