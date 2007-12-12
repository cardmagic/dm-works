require File.dirname(__FILE__) + "/spec_helper"
require 'data_mapper/adapters/postgresql_adapter'

describe DataMapper::Adapters::PostgresqlAdapter::Mappings::Column do
  it "should be able to set check-constraints on columns" do
    mappings = DataMapper::Adapters::PostgresqlAdapter::Mappings
    table    = mappings::Table.new(database(:mock).adapter, "Zebu")
    column   = mappings::Column.new(database(:mock).adapter, table, :age,
                 :integer, 1, { :check => "age > 18"})
    column.to_long_form.should match(/CHECK \(age > 18\)/)
  end
end
