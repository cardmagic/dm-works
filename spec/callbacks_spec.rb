describe DataMapper::Callbacks do
  
  it "should allow for a callback to be set, then called" do
    
    class Tenor
      include DataMapper::CallbacksHelper
      
      attr_accessor :name
      
      def initialize(name)
        @name = name
      end
      
      before_save 'name = "bob"'
      before_validation { |instance| instance.name = 'Barry White Returns!' }

    end unless defined?(Tenor)
    
    barry = Tenor.new('Barry White')
    
    Tenor::callbacks.execute(:before_save, barry)
    barry.name.should == 'Barry White'
    
    Tenor::callbacks.execute(:before_validation, barry)
    barry.name.should == 'Barry White Returns!'
  end
  
end