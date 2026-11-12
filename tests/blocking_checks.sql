/*
Runs sp_WhoIsActive while one session holds a lock and another waits behind it,
so the lock, task and wait parsing sees real data. Run it after
blocking_holder.sql and blocking_waiter.sql are both started. Any failure
raises an error, and sqlcmd -b turns that into a non-zero exit code.
*/
SET NOCOUNT ON;

/* Wait up to 60 seconds for the waiter to be blocked */
DECLARE @tries int = 0;
WHILE @tries < 60
    AND NOT EXISTS
    (
        SELECT 1
        FROM sys.dm_exec_requests AS r
        WHERE r.blocking_session_id > 0
        AND   r.database_id = DB_ID()
        AND   r.session_id <> @@SPID
    )
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @tries += 1;
END;

IF @tries >= 60
    THROW 50002, 'The blocking scenario never started: no blocked request found', 1;
GO

/* Each option runs on its own, so an error names the option that broke */
DECLARE
    @args nvarchar(max),
    @failures int = 0;

DECLARE args_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT args
    FROM (VALUES
        (N'@get_locks = 1'),
        (N'@find_block_leaders = 1'),
        (N'@get_task_info = 2'),
        (N'@get_locks = 1, @find_block_leaders = 1, @get_task_info = 2, @get_plans = 1, @get_additional_info = 1, @get_transaction_info = 1, @get_outer_command = 1')
    ) AS v (args);

OPEN args_cursor;
FETCH NEXT FROM args_cursor INTO @args;
WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC (N'EXEC dbo.sp_WhoIsActive @show_own_spid = 1, @show_sleeping_spids = 2, ' + @args);
        PRINT 'PASS: blocking scenario, ' + @args;
    END TRY
    BEGIN CATCH
        SET @failures += 1;
        PRINT 'FAIL: blocking scenario, ' + @args + ' | error ' + CONVERT(varchar(20), ERROR_NUMBER())
            + ' line ' + CONVERT(varchar(20), ERROR_LINE()) + ': ' + ERROR_MESSAGE();
    END CATCH;
    FETCH NEXT FROM args_cursor INTO @args;
END;
CLOSE args_cursor;
DEALLOCATE args_cursor;

IF @failures > 0
    RAISERROR('%d blocking scenario runs failed, see the FAIL lines above', 16, 1, @failures);
GO

/* Capture the output and check that the blocking data shows up in it */
DECLARE @schema varchar(max);

EXEC dbo.sp_WhoIsActive
    @output_column_list = '[session_id][sql_text][query_plan][wait_info][locks][tasks][blocking_session_id][blocked_session_count][additional_info][tran_start_time]',
    @get_locks = 1,
    @get_plans = 1,
    @get_additional_info = 1,
    @get_transaction_info = 1,
    @find_block_leaders = 1,
    @get_task_info = 2,
    @format_output = 0,
    @return_schema = 1,
    @schema = @schema OUTPUT;

SET @schema = REPLACE(@schema, '<table_name>', 'dbo.wia_ci_blocking_out');
EXEC (@schema);

EXEC dbo.sp_WhoIsActive
    @output_column_list = '[session_id][sql_text][query_plan][wait_info][locks][tasks][blocking_session_id][blocked_session_count][additional_info][tran_start_time]',
    @get_locks = 1,
    @get_plans = 1,
    @get_additional_info = 1,
    @get_transaction_info = 1,
    @find_block_leaders = 1,
    @get_task_info = 2,
    @format_output = 0,
    @destination_table = 'dbo.wia_ci_blocking_out';

DECLARE @problems varchar(max) = '';

IF NOT EXISTS (SELECT 1 FROM dbo.wia_ci_blocking_out WHERE blocking_session_id IS NOT NULL)
    SET @problems += ' no row has a blocking_session_id;';
IF NOT EXISTS (SELECT 1 FROM dbo.wia_ci_blocking_out WHERE blocked_session_count > 0)
    SET @problems += ' no row has a blocked_session_count above 0;';
IF NOT EXISTS (SELECT 1 FROM dbo.wia_ci_blocking_out WHERE locks IS NOT NULL)
    SET @problems += ' no row has lock details;';
IF NOT EXISTS (SELECT 1 FROM dbo.wia_ci_blocking_out WHERE wait_info LIKE '%LCK_M_%')
    SET @problems += ' no row shows a LCK_M wait;';

/* sp_WhoIsActive reports many internal errors inside its output instead of raising them */
DECLARE @sql nvarchar(max), @bad nvarchar(max), @p1 nvarchar(50) = N'%query' + N'_error%', @p2 nvarchar(50) = N'%error mess' + N'age=%';
SET @sql = N'';
SELECT @sql = @sql + N'UNION ALL SELECT TOP (1) ''' + c.name + N': '' + LEFT(v, 400) FROM (SELECT CONVERT(nvarchar(max), ' + QUOTENAME(c.name) + N') AS v FROM dbo.wia_ci_blocking_out' + CASE WHEN c.name IN (N'sql_text', N'sql_command') THEN N' WHERE session_id = @@SPID' ELSE N'' END + N') AS t WHERE v LIKE @p1 OR v LIKE @p2 '
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID('dbo.wia_ci_blocking_out')
AND   c.system_type_id IN (167, 175, 231, 239, 241); -- varchar, char, nvarchar, nchar, xml

SET @bad = N'';
IF @sql <> N''
BEGIN
    SET @sql = N'SELECT @bad = @bad + N'' | '' + col FROM (' + STUFF(@sql, 1, 10, N'') + N') AS x (col)';
    EXEC sys.sp_executesql @sql, N'@p1 nvarchar(50), @p2 nvarchar(50), @bad nvarchar(max) OUTPUT', @p1, @p2, @bad OUTPUT;
END;
IF @bad <> N''
    SET @problems += ' these columns contain an error marker:' + @bad + ';';

DROP TABLE dbo.wia_ci_blocking_out;

IF @problems <> ''
    RAISERROR('Blocking scenario output is missing data:%s', 16, 1, @problems);

PRINT 'PASS: blocking scenario output has blocker, blocked count, locks and lock wait';
GO
