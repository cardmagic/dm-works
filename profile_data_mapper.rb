require 'example'
require 'ruby-prof'

# RubyProf, making profiling Ruby pretty since 1899!
def profile(&b)
  result = RubyProf.profile &b

  printer = RubyProf::GraphHtmlPrinter.new(result)
  File::open('profile_results.html', 'w+') do |file|
    printer.print(file, 0)
  end
end