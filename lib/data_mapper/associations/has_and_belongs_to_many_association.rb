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
      
      def quoted_left_foreign_key
        @left_foreign_key || @left_foreign_key = begin
          adapter.quote_table_name(@options[:left_foreign_key] || table.default_foreign_key)
        end
      end
      
      def quoted_right_foreign_key
        @right_foreign_key || @right_foreign_key = begin
          adapter.quote_table_name(@options[:right_foreign_key] || association_table.default_foreign_key)
        end
      end
      
      def association_table
        @association_table || (@association_table = adapter[constant])
      end
      
      def join_table_name
        @join_table_name || @join_table_name = begin
          @options[:join_table] || begin
            [ table.name.to_s, database.schema[constant].name.to_s ].sort.join('_')
          end
        end
      end
      
      def quoted_join_table_name
        adapter.quote_table_name(join_table_name)
      end
      
      def to_sql
        <<-EOS.compress_lines
          JOIN #{quoted_join_table_name} ON
            #{quoted_join_table_name}.#{quoted_left_foreign_key} = #{table.key.to_sql(true)}
          JOIN #{association_table.to_sql} ON
            #{association_table.key.to_sql(true)} = #{quoted_join_table_name}.#{quoted_right_foreign_key}
        EOS
      end
      
      # Define the association instance method (i.e. Project#tasks)
      def define_accessor(klass)
        klass.class_eval <<-EOS
          def #{@association_name}
            @#{@association_name} || (@#{@association_name} = HasAndBelongsToManyAssociation::Set.new(self, #{@association_name.inspect}))
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
              @instance.session.all(
                association.constant,
                association.foreign_key.to_sym => @instance.loaded_set.map(&:key)
              ).group_by(&association.foreign_key.to_sym).each do |key,instances|
                if instance = @instance.loaded_set.find { |entry| entry.key == key }
                  instance.send(@association_name).set(instances)
                end
              end
              
              @entries              
            end
          end
        end

        def set(results)
          @entries = results
        end

        def inspect
          @entries.inspect
        end
      end
    end # class HasAndBelongsToManyAssociation
    
  end # module Associations
end # module DataMapper