describe('A tree') do
  
  before(:all) do
    class Node < DataMapper::Base
      property :name, :string

      belongs_to :parent, :class => 'Node'
      has_many :children, :class => 'Node', :foreign_key => 'parent_id'
    end
    
    database.schema[Node].drop!
    database.save(Node)
  end    

  it 'should work' do
    root = Node.new(:name => 'root')

    one = Node.new(:name => 'one')
    two = Node.new(:name => 'two')

    root.children << one << two

    one_one = Node.new(:name => 'one_one')
    one_two = Node.new(:name => 'one_two')
    one.children << one_one << one_two

    two_one = Node.new(:name => 'two_one')
    two_two = Node.new(:name => 'two_two')
    two.children << two_one << two_two

    root.save

    grand = Node[:name => 'root']
    root.should_not == grand # false since +root+ and +grand+ are in different sessions.

    grand.children[0].children[0].name.should == 'one_one'
  end
  
end