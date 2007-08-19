module DataMapper
  
  module CallbacksHelper
    
    def self.included(base)
      base.extend(ClassMethods)
      
      # Declare helpers for the standard callbacks
      Callbacks::EVENTS.each do |name|
        base.class_eval <<-EOS
          def self.#{name}(string = nil, &block)
            if string.nil?
              callbacks.add(:#{name}, block)
            else
              callbacks.add(:#{name}, string)
            end
          end
        EOS
      end
    end
    
    module ClassMethods
      def callbacks
        @callbacks || ( @callbacks = DataMapper::Callbacks.new )
      end
    end
  end
  
  class Callbacks
  
    EVENTS = [
      :before_materialize, :after_materialize,
      :before_save, :after_save,
      :before_create, :after_create,
      :before_update, :after_update,
      :before_destroy, :after_destroy,
      :before_validation, :after_validation
      ]
      
    def initialize
      @callbacks = Hash.new do |h,k|
        raise 'Callback names must be Symbols' unless k.kind_of?(Symbol)
        h[k] = []
      end
    end
    
    def execute(name, *args)
      @callbacks[name].all? do |callback|
        if callback.kind_of?(String)
          args.first.instance_eval(callback)
        else
          callback[*args]
        end
      end
    end
    
    def add(name, block)
      callback = @callbacks[name]
      raise ArgumentError.new("You didn't specify a callback in either string or block form.") if block.nil?
      callback << block
    end
  end
  
end