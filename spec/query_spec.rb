require File.dirname(__FILE__) + "/spec_helper"

describe('A query') do
  
  it 'should return a simple Array of primitives' do
    database.query("SELECT name FROM zoos").all? do |entry|
      entry.kind_of?(String)
    end.should == true
  end
  
end