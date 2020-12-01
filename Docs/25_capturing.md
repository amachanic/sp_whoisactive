# sp_whoisactive: Capturing the Output

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [The Output of Your Dreams](24_output.md)	Next: [Delta Force](26_delta.md)
------

[The prior article](24_output.md) was about configuring the output based on what *you* want to see. **This one is about taking that perfect output and persisting it.**

There are many reasons that you might like to store the results of a Who is Active call to a table. Some of the real use cases that I’ve been told about by Who is Active users include:

- Scheduled monitoring. Capturing the results of Who is Active calls in 5 or 10 minute intervals to see what’s happening on the database server throughout the day (or night)
- Using it as part of a build process, to verify that the correct things are happening in the correct order at the correct times
- Using it as part of an exception handling system that automatically calls Who is Active every time an error occurs, to snapshot the current state of the database instance

And there are various other use cases in addition to these. The point is that there are a number of reasons that you might want to capture the output.

**Unfortunately, it’s not as simple a task as you might think.** The first time I tried to make it work, I did something like:

```sql
CREATE TABLE #output
(
  ...
)

INSERT #output
EXEC sp_WhoIsActive
```

This approach failed miserably. If you try it, as I did, you’ll see the following error message:

```sql
Msg 8164, Level 16, State 1, Procedure sp_WhoIsActive, Line 3086
An INSERT EXEC statement cannot be nested.
```

Who is Active uses a number of INSERT EXEC statements, and they cannot be easily changed or removed, so for a while it seemed like all was lost. After a bit of brainstorming, however, I realized that I could simply build yet another INSERT EXEC into Who is Active—one that will insert into a table of your choice.

Of course, first you need a table. And if you’ve been reading this series you’re no doubt aware that the output shape returned by Who is Active is extremely dynamic in nature, and depends on which parameters are being used. So the first option I added was **a method by which you can get the output schema.** Two parameters are involved: If *@return_schema* is set to **1**, the schema shape will be returned in an *OUTPUT* parameter called *@schema*. This is best shown by way of example:

```sql
DECLARE @s VARCHAR(MAX)

EXEC sp_WhoIsActive
  @output_column_list = '[temp%]',
  @return_schema = 1,
  @schema = @s OUTPUT

SELECT @s
```

The idea is that you set up your Who is Active call with all of the options you’d like, then bolt on the *@return_schema* and *@schema* parameters. Here the column list is being restricted to only those columns having to do with *tempdb*. If you run this code, the *SELECT* will return the following result:

```sql
CREATE TABLE <table_name> ( [tempdb_allocations] varchar(30) NULL,[tempdb_current] varchar(30) NULL)
```

This result can be modified by replacing the “<table_name>” placeholder with the name of the table you actually want to persist the results to. Of course this can be done either manually or automatically—after the call to Who is Active, the text is sitting in a variable, so a simple call to *REPLACE* is all that’s needed. That call could even be followed up by a call to execute the result and create the table...

```sql
DECLARE @s VARCHAR(MAX)

EXEC sp_WhoIsActive
  @output_column_list = '[temp%]',
  @return_schema = 1,
  @schema = @s OUTPUT

SET @s = REPLACE(@s, '<table_name>', 'tempdb.dbo.monitoring_output')

EXEC(@s)
```

**Of course now you probably want to put something into the table**. Crazy! To do this, drop the *@return_schema* and *@schema* parameters and replace them with *@destination_table*—the name of the table into which the results should be inserted:

```sql
EXEC sp_WhoIsActive
  @output_column_list = '[temp%]',
  @destination_table = 'tempdb.dbo.monitoring_output'
```

Now the results of the call will be inserted into the destination table. Just remember that every time you change the Who is Active options, you’ll have to re-acquire the output shape. Even a small change, such as adding an additional column to the output list, will result in a catastrophic error.

```sql
EXEC sp_WhoIsActive
  @output_column_list = '[session_id][temp%]',
  @destination_table = 'tempdb.dbo.monitoring_output'
```

```sql
Msg 213, Level 16, State 1, Line 1
Column name or number of supplied values does not match table definition.
```

**How far you take this feature depends on how creative you are**. Some of you have come up with elaborate schemes, but I generally keep it simple. Something that I like to do is to set up a short semi-automated process by using Management Studio’s *GO [N]* option. I use this when I’m doing intense debugging, and will do something like:

```sql
DECLARE @s VARCHAR(MAX)

EXEC sp_WhoIsActive
  @format_output = 0,
  @return_schema = 1,
  @schema = @s OUTPUT

SET @s = REPLACE(@s, '<table_name>', 'tempdb.dbo.quick_debug')

EXEC(@s)
GO

EXEC sp_WhoIsActive
  @format_output = 0,
  @destination_table = 'tempdb.dbo.quick_debug'

WAITFOR DELAY '00:00:05'
GO 60
```

This will first create a table in *tempdb*, after which it will collect the results every five seconds for a five-minute period. I set *@format_output* to **0** in order to get rid of the text formatting so that I can more easily work with the numeric data. **The results can be correlated to performance counters or other external information** using the [collection_time] column, which was added to Who is Active specifically to support automated data collection.

------
Prior: [The Output of Your Dreams](24_output.md)	Next: [Delta Force](26_delta.md)
------
