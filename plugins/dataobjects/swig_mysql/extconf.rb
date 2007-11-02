require 'mkmf'
require 'open3'

def config_value(type)
  ENV["MYSQL_#{type.upcase}"] || mysql_config(type)
end

def mysql_config(type)

  sin, sout, serr = Open3.popen3("mysql_config5 --#{type}")
  
  unless serr.read.empty?
    sin, sout, serr = Open3.popen3("mysql_config --#{type}")
  end
  
  unless serr.read.empty?
    raise "mysql_config not found"
  end
  
  sout.readline.chomp[2..-1]
end

$inc, $lib = dir_config('mysql', config_value('include'), config_value('libs_r')) 

def have_build_env
  libs = ['m', 'z', 'socket', 'nsl']
  while not find_library('mysqlclient', 'mysql_query', config_value('libs'), $lib, "#{$lib}/mysql") do
    exit 1 if libs.empty?
    have_library(libs.shift)
  end
  true
  # have_header('mysql.h')
end

required_libraries = [] #%w(m z socket nsl)
desired_functions = %w(mysql_ssl_set)
# compat_functions = %w(PQescapeString PQexecParams)

if have_build_env
  $CFLAGS << ' -Wall '
  dir_config("mysql_c")
  create_makefile("mysql_c")
else
  puts 'Could not find MySQL build environment (libraries & headers): Makefile not created'
end