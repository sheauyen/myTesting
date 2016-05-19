set	wrap off
set linesize 100
set	feedback off
set	pagesize 0
set	verify off
set termout off

spool ytmpy.sql


prompt  select
select  lower(column_name)||'||chr(9)||'
from    user_tab_columns
where   table_name = upper('&1') and
    column_id != (select max(column_id) from user_tab_columns where
             table_name = upper('&1'))
order by column_id
/
select  lower(column_name)
from    user_tab_columns
where   table_name = upper('&1') and
    column_id = (select max(column_id) from user_tab_columns where
             table_name = upper('&1'))
			 order by column_id
/
prompt  from    &1
prompt  /

spool off
set termout on
@ytmpy.sql
exit
