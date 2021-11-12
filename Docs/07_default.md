# sp_whoisactive: Default Columns

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [Options](06_options.md)	Next: [Active Request, Sleeping Session](08_requests.md)
------

### Part of the battle of writing Who is Active is achieving the proper level of balance between enough information and too much information.

It’s important to return sufficient data to help debug the most common problems without users having to tweak the parameters. And it’s important to restrict the amount of data sent back so that the default output is not overwhelming, nor is the performance of the procedure sacrificed.

Following are the current default columns, broken into four basic categories:

#### Time and Status
```sql
[dd hh:mm:ss.mss]
[start_time]
[percent_complete]
[collection_time]
[status]
``` 

#### Identifiers
```sql
[session_id]
[request_id]
[login_name]
[host_name]
[database_name]
[program_name]
``` 

#### Things Slowing Down Your Query
```sql
[wait_info]
[blocking_session_id]
``` 

#### Things Your Session is Doing
```sql
[sql_text]
[CPU]
[tempdb_allocations]
[tempdb_current]
[reads]
[writes]
[physical_reads]
[used_memory]
[open_tran_count]
```

Each set of columns deserves some description, and we’ll start with **Time and Status**. These columns tell you how long your query has been running ([start_time] and its cousin, the “convenience column” [dd hh:mm:ss.mss]), how much longer things might be running ([percent_complete]), whether anything is running at all ([status]), and a record of when you asked ([collection_time]).

The **Identifiers** are ways of telling one session—or class of sessions—apart from another. The [session_id] and [request_id] columns are, of course, SQL Server’s way of doing this, while the rest of the columns are more human-readable. Note that [request_id] will almost always have a value of 0 for active requests (those where the [status] column has any value other than “sleeping”), and NULL for sleeping sessions. This is not quite the same as the way the data is represented in the sysprocesses DMV, but I don’t think it makes sense to have any [request_id] when there is no request. To see a value greater than 0, you’ll have to use MARS in your application. Not a common thing, which is why this column shows up on the far righthand side of the output.

The **Things Slowing Down Your Query** columns describe wait states and information about blocking. I’ll get into these in detail in a later post.

Finally, the **Things Your Session is Doing** columns give information about what is happening, or has happened, on behalf of your session. At this point in the series it’s worth sharing further information about a few of the less obvious of these columns:

- **The most confusing of these columns are those related to tempdb**. Each of the columns reports a number of 8 KB pages. The [tempdb_allocations] column is collected directly from the tempdb-related DMVs, and indicates how many pages were allocated in tempdb due to temporary tables, LOB types, spools, or other consumers. The [tempdb_current] column is computed by subtracting the deallocated pages information reported by the tempdb DMVs from the number of allocations. Seeing a high number of allocations with a small amount of current pages means that your query may be slamming tempdb, but is not causing it to grow. Seeing a large number of current pages means that your query may be responsible for all of those auto-grows you keep noticing.
- The [used_memory] column is also reported based on a number of 8 KB pages. The number a combination of both procedure cache memory and workspace memory grant.
- **[open_tran_count] is by far the most useful column that Who is Active pulls from the deprecated sysprocesses view**. And only from that view, since Microsoft has not bothered replicating it elsewhere. It can be used not only to tell whether the session has an active transaction, but also to find out how deeply nested the transaction is. This is invaluable information when debugging situations where applications open several nested transactions and don’t send enough commits to seal the deal.

------
Prior: [Options](06_options.md)	Next: [Active Request, Sleeping Session](08_requests.md)
------
