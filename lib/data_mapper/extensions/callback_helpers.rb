require 'data_mapper/callbacks'

module DataMapper
  module Extensions
    
    module CallbackHelpers
    
      def self.included(base)
        base.extend(ClassMethods)
        
        # declare helpers for the standard callbacks
        Callbacks::EVENTS.each do |name|
          base.class_eval <<-EOS
            def self.#{name}(string = nil, &block)
              if string.nil?
                callbacks.add(:#{name}, &block)
              else
                callbacks.add(:#{name}, string)
              end
            end
          EOS
        end
      end
      
      module ClassMethods
        
        def callbacks
          @callbacks ||= Callbacks.new
        end
      end
      
    end
    
  end
end