require 'data_mapper/adapters/sql_adapter'

class MockAdapter < DataMapper::Adapters::SqlAdapter
  COLUMN_QUOTING_CHARACTER = "`"
  TABLE_QUOTING_CHARACTER = "`"
  
  def delete(instance_or_klass, options = nil)
  end
  
  def save(session, instance)
  end
  
  def load(session, klass, options)
  end
  
  def table_exists?(name)
    true
  end
  
end
