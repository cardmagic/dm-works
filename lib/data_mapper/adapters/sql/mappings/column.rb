module DataMapper
  module Adapters
    module Sql
      module Mappings
    
        # TODO: There are of course many more options to add here.
        # Ordinal, Length/Size, Nullability are just a few.
        class Column
    
          attr_accessor :table, :name, :type, :options
    
          def initialize(adapter, table, name, type, ordinal, options = {})
            @adapter = adapter
            @table = table
            @name, @type, @options = name.to_sym, type, options
            @ordinal = ordinal
            
            @key = @options[:key] == true || @options[:serial] == true
            @nullable = @options.has_key?(:nullable) ? @options[:nullable] : !@key
            @lazy = @options.has_key?(:lazy) ? @options[:lazy] : @type == :text
            @serial = @options[:serial] == true
            @default = @options[:default]
            
            (class << self; self end).class_eval <<-EOS
              def type_cast_value(value)
                @adapter.type_cast_#{type}(value)
              end
            EOS
          end
          
          def ordinal
            @ordinal
          end
    
          def lazy=(value)
            @lazy = value
          end
    
          # Determines if the field should be lazy loaded.
          # You can set this explicitly, or accept the default,
          # which is false for all but text fields.
          def lazy?
            @lazy
          end
      
          def nullable?
            @nullable
          end
      
          def key?
            @key
          end
          
          def serial?
            @serial
          end
          
          def default
            @default
          end
          
          def to_sym
            @name
          end
      
          def instance_variable_name
            @instance_variable_name || (@instance_variable_name = "@#{@name.to_s.gsub(/\?$/, '')}".freeze)
          end
      
          def to_s
            @name.to_s
          end
      
          def column_name
            @column_name || (@column_name = (@options.has_key?(:column) ? @options[:column].to_s : name.to_s.gsub(/\?$/, '')).freeze)
          end
      
          def to_sql(include_table_name = false)
            if include_table_name
              @to_sql_with_table_name || @to_sql_with_table_name = begin
                (@table.to_sql + '.' + @adapter.quote_column_name(column_name)).freeze
              end
            else
              @to_sql || (@to_sql = @adapter.quote_column_name(column_name).freeze)
            end
          end
      
          def size
            @size || begin
              return @size = @options[:size] if @options.has_key?(:size)
              return @size = @options[:length] if @options.has_key?(:length)
          
              @size = case type
                when :integer then 4
                when :string, :class then 50
                else nil
              end
            end
          end
      
          def inspect
            "#<%s:0x%x @name=%s, @type=%s, @options=%s>" % [self.class.name, (object_id * 2), to_sql, type.inspect, options.inspect]
          end
          
          def to_long_form
            @to_long_form || begin
              @to_long_form = "#{to_sql} #{type_declaration}"
              
              unless nullable? || not_null_declaration.blank?
                @to_long_form << " #{not_null_declaration}"
              end
              
              if key? && serial? && !primary_key_declaration.blank?
                @to_long_form << " #{primary_key_declaration}"
              end
              
              if serial? && !serial_declaration.blank?
                @to_long_form << " #{serial_declaration}"
              end
              
              unless default.nil? || (value = default_declaration).blank?
                @to_long_form << " #{value}"
              end
        
              @to_long_form
            end
          end
          
          def <=>(other)
            ordinal <=> other.ordinal
          end
          
          def hash
            name.hash
          end
          
          def eql?(other)
            name == other.name
          end
          
          private
          
          def primary_key_declaration
            "PRIMARY KEY"
          end
          
          def type_declaration
            sql = "#{@adapter.class::TYPES[type] || type}"
            sql << "(#{size})" unless size.nil?
            sql
          end
          
          def not_null_declaration
            "NOT NULL"
          end
          
          def serial_declaration
            "AUTO_INCREMENT"
          end
          
          def default_declaration
            @adapter.connection { |db| db.create_command("DEFAULT ?").escape_sql([default]) }
          end
      
        end
    
      end
    end
  end
end
