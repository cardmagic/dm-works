require 'rexml/document'

begin
  require 'json/ext'
rescue LoadError
  require 'json/pure'
end

module DataMapper
  module Support
    module Serialization
      
      def to_yaml(opts = {})
        
        YAML::quick_emit( object_id, opts ) do |out|
          out.map(nil, to_yaml_style ) do |map|
            session.table(self).columns.each do |column|
              lazy_load!(column.name) if column.lazy?
              value = instance_variable_get(column.instance_variable_name)
              map.add(column.to_s, value.is_a?(Class) ? value.to_s : value)
            end
            (self.instance_variable_get("@yaml_added") || []).each do |k,v|
              map.add(k.to_s, v)
            end
          end
        end
        
      end
      
      def to_xml
        doc = REXML::Document.new
        
        table = session.table(self.class)
        root = doc.add_element(Inflector.underscore(self.class.name))
        
        key_attribute = root.attributes << REXML::Attribute.new(table.key.to_s, key)
        
        # Single-quoted attributes are ugly. :p
        # NOTE: I don't want to break existing REXML specs for everyone, so I'm
        # overwriting REXML::Attribute#to_string just for this instance.
        def key_attribute.to_string
          %Q[#@expanded_name="#{to_s().gsub(/"/, '&quot;')}"] 
        end
        
        table.columns.each do |column|
          next if column.key?
          value = send(column.name)
          node = root.add_element(column.to_s)
          node << REXML::Text.new(value.to_s) unless value.nil?
        end
        
        doc.to_s
      end
      
      def to_json(*a)
        table = session.table(self.class)
        
        result = '{ '
        
        result << table.columns.map do |column|
          "#{column.name.to_json}: #{send(column.name).to_json(*a)}"
        end.join(', ')
        
        result << ' }'
        result
      end
    end
  end # module Support
end # module DataMapper