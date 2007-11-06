module DataMapper
  module AutoMigrations
    def auto_migrate!
      if self::subclasses.empty?
        database.schema[self].drop!
        database.save(self)
      else
        schema = database.schema
        columns = self::subclasses.inject(schema[self].columns) do |span, subclass|
          span + schema[subclass].columns
        end

        table_name = schema[self].name.to_s
        table = schema[table_name]
        columns.each do |column|
          table.add_column(column.name, column.type, column.options)
        end

        table.drop!
        table.create!
      end
    end
    
    private
    def create_table(table)
      
    end
    
    def modify_table(table, columns)
      
    end
  end
end