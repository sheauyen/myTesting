@echo off

if "%1"=="" goto :usage
if "%2"=="" goto :usage


sqlplus -s %1 @sqlldr_exp.sql %2

goto :done

:Usage

echo "usage 		sqlldr_exp un/pw [tables|views]"
echo "example 	sqlldr_exp scott/tiger emp dept"
echo "description 	Select over standard out all rows of table or view with "
echo "        		columns delimited by tabs."

:done
