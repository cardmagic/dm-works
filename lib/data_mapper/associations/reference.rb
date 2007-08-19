module DataMapper
  
  module Associations
    
    class Reference
  
      def initialize(instance, association_name)
        @instance, @association_name = instance, association_name
      end
  
      def association
        @association || (@association = @instance.session.schema[@instance.class].association(@association_name))
      end
  
    end
  end

end