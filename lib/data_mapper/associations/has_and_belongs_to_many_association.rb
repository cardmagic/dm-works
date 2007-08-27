module DataMapper
  module Associations
    
    class HasAndBelongsToManyAssociation
      
      attr_reader :adapter, :table
      
      def initialize(klass, association_name, options)
        @adapter = database.adapter
        @table = adapter[klass]
        @association_name = association_name.to_sym
        @options = options
        
        define_accessor(klass)
      end
      
      def name
        @association_name
      end

      def foreign_name
        @foreign_name || (@foreign_name = (@options[:foreign_name] || @table.name).to_sym)
      end
      
      def constant
        @associated_class || @associated_class = begin
        
          if @options.has_key?(:class) || @options.has_key?(:class_name)
            associated_class_name = (@options[:class] || @options[:class_name])
            if associated_class_name.kind_of?(String)
              Kernel.const_get(Inflector.classify(associated_class_name))
            else
              associated_class_name
            end
          else
            Kernel.const_get(Inflector.classify(@association_name))
          end
          
        end
      end

      def association_columns
        association_table.columns.reject { |column| column.lazy? } + join_columns
      end
      
      def join_columns
        [ left_foreign_key, right_foreign_key ]
      end
      
      def association_table
        @association_table || (@association_table = adapter[constant])
      end
      
      def join_table
        @join_table || @join_table = begin 
          join_table_name = @options[:join_table] || 
            [ table.name.to_s, database.schema[constant].name.to_s ].sort.join('_')
            
          adapter[join_table_name]
        end        
      end
      
      def left_foreign_key
        @left_foreign_key || @left_foreign_key = begin
          join_table.add_column(
            (@options[:left_foreign_key] || table.default_foreign_key),
            :integer, {})
        end
      end

      def right_foreign_key
        @right_foreign_key || @right_foreign_key = begin
          join_table.add_column(
            (@options[:right_foreign_key] || association_table.default_foreign_key),
            :integer, {})
        end
      end
      
      def to_sql
        <<-EOS.compress_lines
          JOIN #{join_table.to_sql} ON
            #{left_foreign_key.to_sql(true)} = #{table.key.to_sql(true)}
          JOIN #{association_table.to_sql} ON
            #{association_table.key.to_sql(true)} = #{right_foreign_key.to_sql(true)}
        EOS
      end
      
      def to_shallow_sql
        <<-EOS.compress_lines
          JOIN #{join_table.to_sql} ON
            #{left_foreign_key.to_sql(true)} = #{table.key.to_sql(true)}
        EOS
      end
      
      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)
        klass.class_eval <<-EOS
          def #{@association_name}
            @#{@association_name} || (@#{@association_name} = HasAndBelongsToManyAssociation::Set.new(self, #{@association_name.inspect}))
          end
          
          def #{@association_name}=(value)
            #{@association_name}.set(value)
          end
        EOS
      end
      
      class Set
        
        include Enumerable
        
        def initialize(instance, association_name)
          @instance, @association_name = instance, association_name
        end
        
        def association
          @association || (@association = @instance.session.schema[@instance.class].associations[@association_name])
        end
        
        def each
          entries.each { |item| yield item }
        end

        def size
          entries.size
        end
        alias length size

        def [](key)
          entries[key]
        end

        def empty?
          entries.empty?
        end
        
        def entries
          @entries || @entries = begin

            if @instance.loaded_set.nil?
              []
            else
              
              associated_items = Hash.new { |h,k| h[k] = [] }
              left_key_index = nil
              association_constant = association.constant
              left_foreign_key = association.left_foreign_key
              
              matcher = lambda do |instance,columns,row|
                
                # Locate the column for the left-key.
                unless left_key_index
                  left_key_index = columns.index(association.left_foreign_key)
                end
                
                if instance.kind_of?(association_constant)
                  associated_items[left_foreign_key.type_cast_value(row[left_key_index])] << instance
                end
              end
                
              @instance.session.all(association.constant,
                left_foreign_key => @instance.loaded_set.map(&:key),
                :shallow_include => association.foreign_name,
                :intercept_load => matcher
              )
              
              # do stsuff with associated_items hash.
              setter_method = "#{@association_name}=".to_sym
              
              @instance.loaded_set.each do |entry|
                entry.send(setter_method, associated_items[entry.key])
              end # @instance.loaded_set.each
              
              @entries              
            end
          end
        end

        def set(results)
          @entries = results
        end

        def inspect
          entries.inspect
        end
      end
    
    end # class HasAndBelongsToManyAssociation
    
  end # module Associations
end # module DataMapper