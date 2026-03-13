# sp_whoisactive: Getting More Information

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [Is This Normal?](17_normal.md)	Next: [Why Am I Blocked?](19_whyblocked.md)
------

#### Sometimes you just need more.

With over 20 columns in the default output plus several more than can be dynamically enabled and disabled, Who is Active was already overwhelming enough for certain users. But requests kept pouring in for various additional information—metrics to help debug trickier situations and edge cases.

Rather than cluttering the output, I decided to create a single, special-purpose column for everything that’s not quite important enough to be on its own in the output. The [additional_info] column is an XML column that returns a document with a root node called <additional_info>. **What’s inside of the node depends on a number of things**, but by default you can expect to see:

- text_size
- language
- date_format
- date_first
- quoted_identifier
- arithabort
- ansi_null_dflt_on
- ansi_defaults
- ansi_warnings
- ansi_padding
- ansi_nulls
- concat_null_yields_null
- transaction_isolation_level
- lock_timeout
- deadlock_priority
- row_count

Rather than repeat the documentation, I’ll point you to the [BOL entry for sys.dm_exec_requests](http://msdn.microsoft.com/en-us/library/ms177648.aspx) for information about what all of these mean. Most of them are various settings that can be manipulated by a given user, batch, or stored procedure. They impact the results of a query and, in some cases, its plan. So it’s a good idea to be able to pull them up when needed.

Beyond these, the [additional_info] column might also contain various other pieces of information, depending on which options are selected and what happens to be running. For example, **if a SQL Agent job is running [additional_info] will be populated with**:

- job_id: the identifier for the job in MSDB
- job_name: the name of the job, from MSDB
- step_id: the identifier for the job step in MSDB
- step_name: the name of the job step, from MSDB
- msdb_query_error: included when an error occurs that renders Who is Active unable to resolve the job and step names

This article is just a quick overview; I’ll cover other things you can expect to see in [additional_info] in a later article. In the meantime, **how do you get all of this information?** Simple:

```sql
EXEC sp_WhoIsActive
  @get_additional_info = 1
```

------
Prior: [Is This Normal?](17_normal.md)	Next: [Why Am I Blocked?](19_whyblocked.md)
------
