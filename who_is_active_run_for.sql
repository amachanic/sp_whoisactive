IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'sp_WhoIsActiveRunFor')
  EXEC ('CREATE PROCEDURE dbo.sp_WhoIsActiveRunFor AS SELECT ''stub version, to be replaced''')
GO

/*********************************************************************************************
sp_WhoIsActiveRunFor v1.0 (2019-02-06)
(C) 2019, Lukas Kronberger

Feedback: https://github.com/amachanic/sp_whoisactive/issues
Updates: https://github.com/amachanic/sp_whoisactive/releases

License: 
  sp_WhoIsActiveRunFor is free to download and use for personal, educational, and internal 
  corporate purposes, provided that this header is preserved. Redistribution or sale 
  of sp_WhoIsActiveRunFor, in whole or in part, is prohibited without the author's express 
  written consent.
*********************************************************************************************/
ALTER PROCEDURE dbo.sp_WhoIsActiveRunFor
(
--~
  --The type for @duration parameter, accepts HOUR, MINUTE or SECOND
  @durationType nvarchar(6),
  @duration int,

  --The type for the @interval parameter, accepts HOUR, MINUTE, SECOND or MILLISECOND
  @intervalType nvarchar(11) = 'SECOND',
  @interval int = 5,

  --If defined the output of sp_WhoIsActive is collected into the specified table
  --If the specified table does not exists, it will be created
  @destination_table VARCHAR(4000) = '',

  --Help! What do I do?
  @help BIT = 0,

  --Copy of sp_WhoIsActive parameters, if you need help with them run:
  --EXECUTE sp_WhoIsActive @help = 1
  @filter sysname = '',
  @filter_type VARCHAR(10) = 'session',
  @not_filter sysname = '',
  @not_filter_type VARCHAR(10) = 'session',
  @show_own_spid BIT = 0,
  @show_system_spids BIT = 0,
  @show_sleeping_spids TINYINT = 1,
  @get_full_inner_text BIT = 0,
  @get_plans TINYINT = 0,
  @get_outer_command BIT = 0,
  @get_transaction_info BIT = 0,
  @get_task_info TINYINT = 1,
  @get_locks BIT = 0,
  @get_avg_time BIT = 0,
  @get_additional_info BIT = 0,
  @find_block_leaders BIT = 0,

  --Are ignored when used with parameter @destination_table
  @output_column_list VARCHAR(8000) = '[dd%][session_id][sql_text][sql_command][login_name][wait_info][tasks][tran_log%][cpu%][temp%][block%][reads%][writes%][context%][physical%][query_plan][locks][%]',
  @sort_order VARCHAR(500) = '[start_time] ASC',
  @format_output TINYINT = 1
--~
)
AS
BEGIN
  IF @destination_table IS NULL
    OR @help IS NULL
  BEGIN
    RAISERROR('Input parameters cannot be NULL', 16, 1);
    RETURN;
  END;

  IF @help = 1
  BEGIN;
    DECLARE @header VARCHAR(MAX);
    DECLARE @params VARCHAR(MAX);

    SELECT 
      @header =
        REPLACE
        (
          REPLACE
          (
            CONVERT
            (
              VARCHAR(MAX),
              SUBSTRING
              (
                t.text, 
                CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94,
                CHARINDEX(REPLICATE('*', 93) + '/', t.text) - (CHARINDEX('/' + REPLICATE('*', 93), t.text) + 94)
              )
            ),
            CHAR(13)+CHAR(10),
            CHAR(13)
          ),
          '	',
          ''
        ),
      @params =
        CHAR(13) +
          REPLACE
          (
            REPLACE
            (
              CONVERT
              (
                VARCHAR(MAX),
                SUBSTRING
                (
                  t.text, 
                  CHARINDEX('--~', t.text) + 5, 
                  CHARINDEX('--~', t.text, CHARINDEX('--~', t.text) + 5) - (CHARINDEX('--~', t.text) + 5)
                )
              ),
              CHAR(13)+CHAR(10),
              CHAR(13)
            ),
            '  ',
            ''
          )
    FROM sys.dm_exec_requests AS r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
    WHERE
      r.session_id = @@SPID;

    WITH
    a0 AS
    (SELECT 1 AS n UNION ALL SELECT 1),
    a1 AS
    (SELECT 1 AS n FROM a0 AS a, a0 AS b),
    a2 AS
    (SELECT 1 AS n FROM a1 AS a, a1 AS b),
    a3 AS
    (SELECT 1 AS n FROM a2 AS a, a2 AS b),
    a4 AS
    (SELECT 1 AS n FROM a3 AS a, a3 AS b),
    numbers AS
    (
      SELECT TOP(LEN(@header) - 1)
        ROW_NUMBER() OVER
        (
          ORDER BY (SELECT NULL)
        ) AS number
      FROM a4
      ORDER BY
        number
    )
    SELECT
      RTRIM(LTRIM(
        SUBSTRING
        (
          @header,
          number + 1,
          CHARINDEX(CHAR(13), @header, number + 1) - number - 1
        )
      )) AS [------header---------------------------------------------------------------------------------------------------------------]
    FROM numbers
    WHERE
      SUBSTRING(@header, number, 1) = CHAR(13);

    WITH
    a0 AS
    (SELECT 1 AS n UNION ALL SELECT 1),
    a1 AS
    (SELECT 1 AS n FROM a0 AS a, a0 AS b),
    a2 AS
    (SELECT 1 AS n FROM a1 AS a, a1 AS b),
    a3 AS
    (SELECT 1 AS n FROM a2 AS a, a2 AS b),
    a4 AS
    (SELECT 1 AS n FROM a3 AS a, a3 AS b),
    numbers AS
    (
      SELECT TOP(LEN(@params) - 1)
        ROW_NUMBER() OVER
        (
          ORDER BY (SELECT NULL)
        ) AS number
      FROM a4
      ORDER BY
        number
    ),
    tokens AS
    (
      SELECT 
        RTRIM(LTRIM(
          SUBSTRING
          (
            @params,
            number + 1,
            CHARINDEX(CHAR(13), @params, number + 1) - number - 1
          )
        )) AS token,
        number,
        CASE
          WHEN SUBSTRING(@params, number + 1, 1) = CHAR(13) THEN number
          ELSE COALESCE(NULLIF(CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number), 0), LEN(@params)) 
        END AS param_group,
        ROW_NUMBER() OVER
        (
          PARTITION BY
            CHARINDEX(',' + CHAR(13) + CHAR(13), @params, number),
            SUBSTRING(@params, number+1, 1)
          ORDER BY 
            number
        ) AS group_order
      FROM numbers
      WHERE
        SUBSTRING(@params, number, 1) = CHAR(13)
    ),
    parsed_tokens AS
    (
      SELECT
        MIN
        (
          CASE
            WHEN token LIKE '@%' THEN token
            ELSE NULL
          END
        ) AS parameter,
        MIN
        (
          CASE
            WHEN token LIKE '--%' THEN RIGHT(token, LEN(token) - 2)
            ELSE NULL
          END
        ) AS description,
        param_group,
        group_order
      FROM tokens
      WHERE
        NOT 
        (
          token = '' 
          AND group_order > 1
        )
      GROUP BY
        param_group,
        group_order
    )
    SELECT
      CASE
        WHEN description IS NULL AND parameter IS NULL THEN '-------------------------------------------------------------------------'
        WHEN param_group = MAX(param_group) OVER() THEN parameter
        ELSE COALESCE(LEFT(parameter, LEN(parameter) - 1), '')
      END AS [------parameter----------------------------------------------------------],
      CASE
        WHEN description IS NULL AND parameter IS NULL THEN '----------------------------------------------------------------------------------------------------------------------'
        ELSE COALESCE(description, '')
      END AS [------description-----------------------------------------------------------------------------------------------------]
    FROM parsed_tokens
    ORDER BY
      param_group, 
      group_order;
    
    RETURN;
  END;

  DECLARE @upperDurationType nvarchar(11) = UPPER(@durationType);
  DECLARE @upperIntervalType nvarchar(11) = UPPER(@intervalType);
  DECLARE @startTime datetime2;

  SET @startTime = SYSDATETIME();

  IF @duration <= 0
  BEGIN
    RAISERROR('Input parameters @number must be greater than zero', 16, 1);
    RETURN;
  END;

  DECLARE @endTime datetime2;

  IF @upperDurationType = 'HOUR' OR @upperDurationType = 'HH'
  BEGIN
    SET @endTime = DATEADD(HOUR, @duration, @startTime);
  END
  ELSE IF @upperDurationType = 'MINUTE' OR @upperDurationType = 'MI' OR @upperDurationType = 'N'
  BEGIN
    SET @endTime = DATEADD(MINUTE, @duration, @startTime);
  END
  ELSE IF @upperDurationType = 'SECOND' OR @upperDurationType = 'SS' OR @upperDurationType = 'S'
  BEGIN
    SET @endTime = DATEADD(SECOND, @duration, @startTime);
  END
  ELSE
  BEGIN
    RAISERROR('Input parameters @upperDurationType must be one of HOUR, MINUTE, SECOND', 16, 1);
    RETURN;
  END;

  DECLARE @firstIntervall datetime2;

  IF @upperIntervalType = 'HOUR' OR @upperIntervalType = 'HH'
  BEGIN
    SET @firstIntervall = DATEADD(HOUR, @interval, @startTime);
  END
  ELSE IF @upperIntervalType = 'MINUTE' OR @upperIntervalType = 'MI' OR @upperIntervalType = 'N'
  BEGIN
    SET @firstIntervall = DATEADD(MINUTE, @interval, @startTime);
  END
  ELSE IF @upperIntervalType = 'SECOND' OR @upperIntervalType = 'SS' OR @upperIntervalType = 'S'
  BEGIN
    SET @firstIntervall = DATEADD(SECOND, @interval, @startTime);
  END
  ELSE IF @upperIntervalType = 'MILLISECOND' OR @upperIntervalType = 'MS'
  BEGIN
    SET @firstIntervall = DATEADD(MILLISECOND, @interval, @startTime);
  END
  ELSE
  BEGIN
    RAISERROR('Input parameters @upperIntervalType must be one of HOUR, MINUTE, SECOND, MILLISECOND', 16, 1);
    RETURN;
  END;

  DECLARE @remainingTime_MS int;
  DECLARE @intervall_MS int;

  SET @remainingTime_MS = DATEDIFF(MILLISECOND, @startTime, @endTime);
  SET @intervall_MS = DATEDIFF(MILLISECOND, @startTime, @firstIntervall);

  IF @intervall_MS > @remainingTime_MS
  BEGIN
    RAISERROR('Input parameter @interval must be less than or equal input parameter @datepart', 16, 1);
    RETURN;
  END;

  -- Set up @destination_table is required
  IF @destination_table <> ''
  BEGIN
    SET @destination_table = 
      --database
      COALESCE(QUOTENAME(PARSENAME(@destination_table, 3)) + '.', '') +
      --schema
      COALESCE(QUOTENAME(PARSENAME(@destination_table, 2)) + '.', '') +
      --table
      COALESCE(QUOTENAME(PARSENAME(@destination_table, 1)), '');

    IF COALESCE(RTRIM(@destination_table), '') = ''
    BEGIN
      RAISERROR('Destination table not properly formatted.', 16, 1);
      RETURN;
    END;

    IF OBJECT_ID(@destination_table) IS NULL
    BEGIN
      DECLARE @s VARCHAR(MAX);

      EXECUTE sp_WhoIsActive
        @filter = @filter,
        @filter_type = @filter_type,
        @not_filter = @not_filter,
        @not_filter_type = @not_filter_type,
        @show_own_spid = @show_own_spid,
        @show_system_spids = @show_system_spids,
        @show_sleeping_spids = @show_sleeping_spids,
        @get_full_inner_text = @get_full_inner_text,
        @get_plans = @get_plans,
        @get_outer_command = @get_outer_command,
        @get_transaction_info = @get_transaction_info,
        @get_task_info = @get_task_info,
        @get_locks = @get_locks,
        @get_avg_time = @get_avg_time,
        @get_additional_info = @get_additional_info,
        @find_block_leaders = @find_block_leaders,
        @format_output = 0,
        @return_schema = 1,
        @schema = @s OUTPUT;

      SET @s = REPLACE(@s, '<table_name>', @destination_table);

      EXECUTE(@s);
    END;
  END;

  DECLARE @before datetime2;
  DECLARE @after datetime2;
  DECLARE @actualWait datetime;
  DECLARE @actualWait_MS int;
  DECLARE @whoIsActiveDuration_MS int;

  DECLARE @ErrorMessage nvarchar(4000);
  DECLARE @ErrorSeverity int;
  DECLARE @ErrorState int;

  WHILE @remainingTime_MS >= @intervall_MS
  BEGIN
    SET @before = SYSDATETIME();

    -- Excute sp_WhoIsActive 
    IF @destination_table <> ''
    BEGIN
      BEGIN TRY
        EXECUTE sp_WhoIsActive
          @filter = @filter,
          @filter_type = @filter_type,
          @not_filter = @not_filter,
          @not_filter_type = @not_filter_type,
          @show_own_spid = @show_own_spid,
          @show_system_spids = @show_system_spids,
          @show_sleeping_spids = @show_sleeping_spids,
          @get_full_inner_text = @get_full_inner_text,
          @get_plans = @get_plans,
          @get_outer_command = @get_outer_command,
          @get_transaction_info = @get_transaction_info,
          @get_task_info = @get_task_info,
          @get_locks = @get_locks,
          @get_avg_time = @get_avg_time,
          @get_additional_info = @get_additional_info,
          @find_block_leaders = @find_block_leaders,
          @format_output = 0,
          @destination_table = @destination_table;
      END TRY
      BEGIN CATCH
        SELECT
          @ErrorMessage = ERROR_MESSAGE(), 
          @ErrorSeverity = ERROR_SEVERITY(), 
          @ErrorState = ERROR_STATE();

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN;
      END CATCH;
    END
    ELSE
    BEGIN
      EXECUTE sp_WhoIsActive
        @filter = @filter,
        @filter_type = @filter_type,
        @not_filter = @not_filter,
        @not_filter_type = @not_filter_type,
        @show_own_spid = @show_own_spid,
        @show_system_spids = @show_system_spids,
        @show_sleeping_spids = @show_sleeping_spids,
        @get_full_inner_text = @get_full_inner_text,
        @get_plans = @get_plans,
        @get_outer_command = @get_outer_command,
        @get_transaction_info = @get_transaction_info,
        @get_task_info = @get_task_info,
        @get_locks = @get_locks,
        @get_avg_time = @get_avg_time,
        @get_additional_info = @get_additional_info,
        @find_block_leaders = @find_block_leaders,
        @format_output = @format_output,
        @output_column_list = @output_column_list,
        @sort_order = @sort_order;
    END;

    SET @after = SYSDATETIME();
    SET @whoIsActiveDuration_MS = DATEDIFF(MILLISECOND, @before, @after);

    IF @whoIsActiveDuration_MS > @intervall_MS
    BEGIN
      SET @remainingTime_MS = @remainingTime_MS - @whoIsActiveDuration_MS;
    END
    ELSE
    BEGIN
      SET @actualWait_MS = @intervall_MS - @whoIsActiveDuration_MS;

      SET @actualWait = DATEADD(MILLISECOND, @actualWait_MS, CONVERT(datetime, 0));
      WAITFOR DELAY @actualWait;

      SET @remainingTime_MS = @remainingTime_MS - @intervall_MS;
    END;
  END;
END;
