require 'data_mapper/adapters/do_adapter'

module DataMapper
  module Adapters
    
    class DoMysqlAdapter < DoAdapter
      module Commands
        class LoadCommand
          def load(reader)          
            # The following blocks are identical aside from the yield.
            # It's written this way to avoid a conditional within each
            # iterator, and to take advantage of the performance of
            # yield vs. Proc#call.
            if block_given?
              reader.each do
                @loaders.each_pair do |klass,loader|
                  row = reader.current_row
                  yield(loader.materialize(row), @columns, row)
                end
              end
            else
              reader.each do
                @loaders.each_pair do |klass,loader|
                  loader.materialize(reader.current_row)
                end
              end
            end
          end
        end
      end
    end # class MysqlAdapter
    
  end # module Adapters
end # module DataMapper