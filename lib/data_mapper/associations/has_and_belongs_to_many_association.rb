module DataMapper
  module Associations
    
    class HasAndBelongsToManyAssociation
      
      attr_reader :adapter, :table
      
      def initialize(klass, association_name, options)
        @adapter = database.adapter
        @table = adapter.table(klass)
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
      
      def activate!
        join_table.create!
      end

      def associated_columns
        association_table.columns.reject { |column| column.lazy? } + join_columns
      end
      
      def join_columns
        [ left_foreign_key, right_foreign_key ]
      end
      
      def association_table
        @association_table || (@association_table = adapter.table(constant))
      end
      
      def join_table
        @join_table || @join_table = begin 
          join_table_name = @options[:join_table] || 
            [ table.name.to_s, database.schema[constant].name.to_s ].sort.join('_')
            
          adapter.table(join_table_name)
        end        
      end
      
      def left_foreign_key
        @left_foreign_key || @left_foreign_key = begin
          join_table.add_column(
            (@options[:left_foreign_key] || table.default_foreign_key),
            :integer, :key => true)
        end
      end

      def right_foreign_key
        @right_foreign_key || @right_foreign_key = begin
          join_table.add_column(
            (@options[:right_foreign_key] || association_table.default_foreign_key),
            :integer, :key => true)
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
      
      def to_insert_sql
        <<-EOS.compress_lines
          INSERT INTO #{join_table.to_sql}
          (#{left_foreign_key.to_sql}, #{right_foreign_key.to_sql})
          VALUES
        EOS
      end
      
      def to_delete_sql
        <<-EOS
          DELETE FROM #{join_table.to_sql}
          WHERE #{left_foreign_key.to_sql} = ?
        EOS
      end
      
      def to_delete_member_sql
        <<-EOS
          DELETE FROM #{join_table.to_sql}
          WHERE #{left_foreign_key.to_sql} = ?
            AND #{right_foreign_key.to_sql} = ?
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
      
      class Set < Associations::Reference
        
        include Enumerable
        
        def initialize(*args)
          super
          @new_members = false
        end
        
        def each
          entries.each { |item| yield item }
        end

        def size
          entries.size
        end
        alias length size
        
        def count
          1
        end
        
        def [](key)
          entries[key]
        end

        def empty?
          entries.empty?
        end
        
        def dirty?
          @new_members || (@entries && @entries.any? { |item| item != @instance && item.dirty? })
        end
        
        def validate_excluding_association(associated, event)
          @entries.blank? || @entries.all? { |item| item.validate_excluding_association(associated, event) }
        end
        
        def save
          unless @entries.nil?
            
            if @new_members || dirty?
              adapter = @instance.session.adapter
              
              adapter.connection do |db|
                command = db.create_command(association.to_delete_sql)
                command.execute_non_query(@instance.key)
              end
            
              unless @entries.empty?
                if adapter.batch_insertable?
                  sql = association.to_insert_sql
                  values = []
                  keys = []
              
                  @entries.each do |member|
                    member.save
                    values << "(?, ?)"
                    keys << @instance.key << member.key
                  end
            
                  adapter.connection do |db|
                    command = db.create_command(sql << ' ' << values.join(', '))
                    command.execute_non_query(*keys)
                  end
              
                else # adapter doesn't support batch inserts...
                  @entries.each do |member|
                    member.save                
                  end
              
                  # Just to keep the same flow as the batch-insert mode.
                  @entries.each do |member|
                    adapter.connection do |db|
                      command = db.create_command("#{association.to_insert_sql} (?, ?)")
                      command.execute_non_query(@instance.key, member.key)
                    end
                  end
                end # if adapter.batch_insertable?
              end # unless @entries.empty?
              
              @new_members = false
            end # if @new_members || dirty?
          end
        end
        
        def <<(member)
          @new_members = true
          entries << member
        end
        
        def clear
          @new_members = true
          @entries = []
        end
        
        def delete(member)
          @new_members = true
          if entries.delete(member)
            @instance.session.adapter.connection do |db|
              command = db.create_command(association.to_delete_member_sql)
              command.execute_non_query(@instance.key, member.key)
            end
            member
          else
            nil
          end
        end
        
        def method_missing(symbol, *args, &block)
          if entries.respond_to?(symbol)
            entries.send(symbol, *args, &block)
          elsif association.associated_table.associations.any? { |assoc| assoc.name == symbol }
            results = []
            each do |item|
              unless (val = item.send(symbol)).blank?
                results << (val.is_a?(Enumerable) ? val.entries : val)
              end
            end
            results.flatten
          else
            super
          end
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
                  columns.each_with_index do |column, index|
                    if column.name == association.left_foreign_key.name
                      left_key_index = index
                      break
                    end
                  end
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