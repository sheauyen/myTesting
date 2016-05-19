@echo off

if "%1"=="" goto :usage
if "%2"=="" goto :usage


sqlplus -s %1 @flat.sql %2

goto :done

:Usage

echo "usage 		flat un/pw [tables|views]"
echo "example 	flat scott/tiger emp dept"
echo "description 	Select over standard out all rows of table or view with "
echo "        		columns delimited by tabs."

:done
