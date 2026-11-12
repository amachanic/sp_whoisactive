/*
Smoke tests for sp_WhoIsActive. Run it with sqlcmd -b in the database that
holds the proc. Each option set runs in its own TRY/CATCH, so one failure does
not hide the others. At the end the script raises an error if anything failed,
and sqlcmd -b turns that error into a non-zero exit code.

Each option set runs twice: once to the screen, and once into a table. The
table run is there because sp_WhoIsActive catches many errors itself and
reports them inside its output (as an attribute or element that has error
in its name) instead of raising them. The script reads the table back and
fails if any of those markers is present.
*/
SET NOCOUNT ON;

DECLARE
    @name varchar(100),
    @args nvarchar(max),
    @failures int = 0,
    @total int = 0,
    @capture bit,
    @sql nvarchar(max),
    @schema varchar(max),
    @bad nvarchar(max) = N'',
    @p1 nvarchar(50) = N'%query' + N'_error%',
    @p2 nvarchar(50) = N'%error mess' + N'age=%';

DECLARE @scenarios table
(
    id int IDENTITY(1, 1) PRIMARY KEY,
    name varchar(100) NOT NULL,
    args nvarchar(max) NOT NULL,
    capture bit NOT NULL
);

DECLARE @own nvarchar(200) = N'@show_own_spid = 1, @show_sleeping_spids = 2';

INSERT @scenarios (name, args, capture)
VALUES
    ('default', @own + N', @show_system_spids = 1', 1),
    ('no parameters', N'', 0),
    ('get_task_info 2', @own + N', @show_system_spids = 1, @get_task_info = 2', 1),
    ('find_block_leaders', @own + N', @show_system_spids = 1, @find_block_leaders = 1', 1),
    ('get_plans', @own + N', @get_plans = 1', 1),
    ('get_plans 2', @own + N', @get_plans = 2', 1),
    ('get_locks', @own + N', @get_locks = 1', 1),
    ('get_transaction_info', @own + N', @get_transaction_info = 1', 1),
    ('get_additional_info', @own + N', @show_system_spids = 1, @get_additional_info = 1', 1),
    ('get_outer_command and get_full_inner_text', @own + N', @get_outer_command = 1, @get_full_inner_text = 1', 1),
    ('delta_interval', @own + N', @show_system_spids = 1, @delta_interval = 1', 1),
    ('get_avg_time', @own + N', @get_avg_time = 1', 1),
    ('get_memory_info', @own + N', @get_memory_info = 1', 1),
    ('all major options', @own + N', @show_system_spids = 1, @get_task_info = 2, @get_plans = 1, @get_locks = 1, @get_transaction_info = 1, @get_additional_info = 1, @find_block_leaders = 1, @get_outer_command = 1, @get_full_inner_text = 1, @get_avg_time = 1, @get_memory_info = 1, @delta_interval = 1', 1),
    ('format_output 0', N'@show_own_spid = 1, @format_output = 0', 1),
    ('format_output 2', N'@show_own_spid = 1, @format_output = 2', 1),
    ('filters', @own + N', @filter = ''%'', @filter_type = ''program'', @not_filter = ''no_such_login'', @not_filter_type = ''login''', 1),
    ('help', N'@help = 1', 0);

DECLARE scenario_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name, args, capture FROM @scenarios ORDER BY id;

OPEN scenario_cursor;
FETCH NEXT FROM scenario_cursor INTO @name, @args, @capture;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @total += 1;
    BEGIN TRY
        EXEC (N'EXEC dbo.sp_WhoIsActive ' + @args);

        IF @capture = 1
        BEGIN
            SET @schema = NULL;
            SET @sql = N'EXEC dbo.sp_WhoIsActive ' + @args + N', @return_schema = 1, @schema = @schema OUTPUT';
            EXEC sys.sp_executesql @sql, N'@schema varchar(max) OUTPUT', @schema OUTPUT;

            SET @schema = REPLACE(@schema, '<table_name>', 'dbo.wia_ci_capture');
            EXEC (@schema);
            EXEC (N'EXEC dbo.sp_WhoIsActive ' + @args + N', @destination_table = ''dbo.wia_ci_capture''');

            SET @sql = N'';
            SELECT @sql = @sql + N'UNION ALL SELECT TOP (1) ''' + c.name + N': '' + LEFT(v, 400) FROM (SELECT CONVERT(nvarchar(max), ' + QUOTENAME(c.name) + N') AS v FROM dbo.wia_ci_capture' + CASE WHEN c.name IN (N'sql_text', N'sql_command') THEN N' WHERE session_id = @@SPID' ELSE N'' END + N') AS t WHERE v LIKE @p1 OR v LIKE @p2 '
            FROM sys.columns AS c
            WHERE c.object_id = OBJECT_ID('dbo.wia_ci_capture')
            AND   c.system_type_id IN (167, 175, 231, 239, 241); -- varchar, char, nvarchar, nchar, xml

            SET @bad = N'';
            IF @sql <> N''
            BEGIN
                SET @sql = N'SELECT @bad = @bad + N'' | '' + col FROM (' + STUFF(@sql, 1, 10, N'') + N') AS x (col)';
                EXEC sys.sp_executesql @sql, N'@p1 nvarchar(50), @p2 nvarchar(50), @bad nvarchar(max) OUTPUT', @p1, @p2, @bad OUTPUT;
            END;
            IF @bad <> N''
                THROW 50003, 'sp_WhoIsActive reported an error inside its own output (an error marker was found), see the columns named in the FAIL line', 1;

            DROP TABLE dbo.wia_ci_capture;
        END;

        PRINT 'PASS: ' + @name;
    END TRY
    BEGIN CATCH
        SET @failures += 1;
        PRINT 'FAIL: ' + @name + ' | error ' + CONVERT(varchar(20), ERROR_NUMBER())
            + ' line ' + CONVERT(varchar(20), ERROR_LINE()) + ': ' + ERROR_MESSAGE();
        IF @bad <> N''
            PRINT 'Columns with an error in them:' + @bad;
        IF OBJECT_ID('dbo.wia_ci_capture', 'U') IS NOT NULL
            DROP TABLE dbo.wia_ci_capture;
    END CATCH;

    SET @bad = N'';

    FETCH NEXT FROM scenario_cursor INTO @name, @args, @capture;
END;

CLOSE scenario_cursor;
DEALLOCATE scenario_cursor;

/* Destination table: build the schema, create the table, then insert into it */
SET @total += 1;
BEGIN TRY
    EXEC dbo.sp_WhoIsActive
        @show_own_spid = 1,
        @get_additional_info = 1,
        @get_locks = 1,
        @find_block_leaders = 1,
        @return_schema = 1,
        @schema = @schema OUTPUT;

    SET @schema = REPLACE(@schema, '<table_name>', 'dbo.wia_ci_destination');
    EXEC (@schema);

    EXEC dbo.sp_WhoIsActive
        @show_own_spid = 1,
        @get_additional_info = 1,
        @get_locks = 1,
        @find_block_leaders = 1,
        @destination_table = 'dbo.wia_ci_destination';

    IF NOT EXISTS (SELECT 1 FROM dbo.wia_ci_destination)
        THROW 50001, 'destination table is empty, expected the own session row', 1;

    PRINT 'PASS: destination table';
END TRY
BEGIN CATCH
    SET @failures += 1;
    PRINT 'FAIL: destination table | error ' + CONVERT(varchar(20), ERROR_NUMBER())
        + ' line ' + CONVERT(varchar(20), ERROR_LINE()) + ': ' + ERROR_MESSAGE();
END CATCH;

IF OBJECT_ID('dbo.wia_ci_destination', 'U') IS NOT NULL
    DROP TABLE dbo.wia_ci_destination;

PRINT CONVERT(varchar(20), @total - @failures) + ' of ' + CONVERT(varchar(20), @total) + ' scenarios passed';

IF @failures > 0
    RAISERROR('%d of %d sp_WhoIsActive scenarios failed, see the FAIL lines above', 16, 1, @failures, @total);
GO
