module DataMapper
  module Support
    module Object
      
      def self.included(base)
        
        nested_constants = Hash.new do |h,k|
          klass = Object
          k.split('::').each do |c|
            klass = klass.const_get(c)
          end
          h[k] = klass
        end
        
        base.instance_variable_set("@nested_constants", nested_constants)
        base.send(:include, ClassMethods)
      end
      
      module ClassMethods
        def recursive_const_get(nested_name)
          @nested_constants[nested_name]
        end
      end
    end
  end
end

class Object #:nodoc:
  include DataMapper::Support::Object
end