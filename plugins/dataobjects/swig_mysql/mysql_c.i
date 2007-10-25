%module mysql_c
%{
#include <mysql.h>
#include <errmsg.h>
#include <mysqld_error.h>
%}

%include "/opt/local/include/mysql5/mysql/mysql.h"