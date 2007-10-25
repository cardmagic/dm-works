require 'spec'
$:.push File.join(File.dirname(__FILE__), '..')
require 'do'

adapter = (ENV["ADAPTER"] || "sqlite3").dup

require "do_#{adapter}"

adapter_module = adapter.dup
adapter_module[0] = adapter_module[0].chr.upcase
$adapter_module = DataObject.const_get(adapter_module)

$connection_string = case adapter
when "sqlite3"
  "dbname=do_rb"
when "mysql"
  "socket=/tmp/mysql.sock user=root dbname=do_rb"
when "postgres"
  "dbname=do_rb"
end

$escape          = $adapter_module::QUOTE_COLUMN
$escaped_columns = ["int", "time", "bool", "date", "str"].map {|x| "#{$escape}#{x}#{$escape}"}.join(", ")
$quote = quote   = $adapter_module::QUOTE_STRING

begin
  c = $adapter_module::Connection.new($connection_string)
  c.open
  cmd = c.create_command("DROP TABLE table1")
  cmd.execute_non_query rescue nil
  if adapter == "mysql"
    sql = <<-SQL
    CREATE TABLE table1 (
      `id` serial NOT NULL,
      `int` int(11) default NULL,
      `time` timestamp,
      `bool` tinyint(1) default NULL,
      `date` date default NULL,
      `str` varchar(20) default NULL,
      PRIMARY KEY (`id`)
    );
    SQL
  elsif adapter == "sqlite3"
    sql = <<-SQL
    CREATE TABLE table1 (
      `id` integer NOT NULL PRIMARY KEY AUTOINCREMENT,
      `int` int(11) default NULL,
      `time` timestamp,
      `bool` tinyint(1) default NULL,
      `date` date default NULL,
      `str` varchar(20) default NULL
    );
    SQL
  elsif adapter == "postgres"
    sql = <<-SQL
    CREATE TABLE table1 (
      "id" serial NOT NULL,
      "int" integer default NULL,
      "time" timestamp,
      "bool" boolean default NULL,
      "date" date default NULL,
      "str" varchar(20) default NULL,
      PRIMARY KEY ("id")
    );
    SQL
  end
  cmd2 = c.create_command(sql)
  cmd2.execute_non_query
  insert1 = adapter == "postgres" ? 
    "INSERT into table1(#{$escaped_columns}) VALUES(NULL, #{quote}#{Time.now.to_s_db}#{quote}, false, #{quote}#{Date.today.to_s}#{quote}, #{quote}foo#{quote})" :
    "INSERT into table1(#{$escaped_columns}) VALUES(NULL, #{quote}#{Time.now.to_s_db}#{quote}, 0, #{quote}#{Date.today.to_s}#{quote}, #{quote}foo#{quote})"
  cmd3 = c.create_command(insert1)
  cmd3.execute_non_query
  insert2 = adapter == "postgres" ?
    "INSERT into table1(#{$escaped_columns}) VALUES(17, #{quote}#{Time.now.to_s_db}#{quote}, true, NULL, NULL)" :
    "INSERT into table1(#{$escaped_columns}) VALUES(17, #{quote}#{Time.now.to_s_db}#{quote}, 1, NULL, NULL)"
  cmd4 = c.create_command(insert2)    
  cmd4.execute_non_query
ensure
  c.close if defined?(c) && c
end