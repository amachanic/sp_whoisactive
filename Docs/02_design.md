# sp_whoisactive: Design Philosophy

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [A Brief History of Activity Monitoring](01_background.md)	Next: [The License](03_license.md)
------

As mentioned in [the background article](01_background.md), I have been working on Who is Active for several years. At first it was a standalone script that I would run in an ad hoc manner when I needed some information, but after a short time it became clear that it made a lot of sense to package it up as a stored procedure.

As time progressed I began adding more and more features on top of the basic functionality, and not surprisingly, the code quickly became extremely complex. In the interest of performance and flexibility I was forced to take what was once a single SQL statement and convert it to utilize dynamic SQL, temporary tables, cursors, error handling, XML, and various other features. Throughout the entire process I’ve attempted to adhere, whenever possible, to a set of basic design principles. These are covered below.

### Show Only Interesting (Relevant) Data

The sp_who* family of stored procedures. Enterprise Manager’s Current Activity screen. Activity Monitor. These tools all have one thing in common that makes them much less useful than they could have been: They show every session that’s connected to the SQL Server instance—whether or not any work is being done. On smaller SQL Server instances this doesn’t matter; you get used to ignoring the various system processes, and figure out where to focus to get the pay dirt—information on what your users are actually up to. But some bigger instances, especially those that back numerous application servers using connection pooling, can have hundreds or thousands of connected, sleeping sessions.

Generally speaking, **when you’re doing activity monitoring, seeing sleeping sessions is a waste of time**. You need to see what’s actively happening on the server, not who has connected and left a session open anytime in recent days. So from the very first versions of Who is Active I simply filtered out anything that was sleeping, with one exception: Sleeping sessions may be holding an open transaction, in which case they may have resources locked.

Who is Active is called “Who is Active” because—by default—it only shows you information about sessions that are actually doing something. If you want to see all of the other sessions, it can do that too. But you’ll have to ask.

### Show Simple and Easily-Digestible Information

Remember session 54 from the background article? Here’s a reminder, via sp_who2:

![F1_01_sp_who2](image/F1_01_sp_who2.jpg)

It’s active (it’s doing something), so we’re interested. We see numerous rows because the granularity of these older tools is per-task, not per-request. We’ll get to tasks in a later post, but in the meantime consider this: **The same exact information has been reported numerous times**. There are not, in fact, numerous sessions using session ID 54, each of which are connected to ADAM03 and each of which are running some kind of SELECT. This is extraneous information that just makes our job of figuring out what’s going on that much more difficult. Even worse, all of those numbers (the CPU and DiskIO columns, in case you’re wondering) are each populated at the task level. If you needed to debug at the task level—and in practice, as an end-user you very, very rarely do—that would be great. But for most of us, a single, aggregated CPU time number works fine, thank you very much. (Assuming, of course, that these CPU numbers are even accurate.)

Here’s the same session, reported in Who is Active:

![F2_01_WIA](image/F2_01_WIA.jpg)

No matter how many tasks this session spins up, Who is Active will still return the exact same number of rows: 1. Part of the actual query, if it’s available, is shown right upfront. You can click on the XML if you want to see the full text. I’ve decided against showing the CPU and disk I/O columns in this screen shot because the values are both 0—it turns out that these numbers are quite often reported inaccurately for parallel requests, so the newer DMVs don’t show them in this case. Therefore, Who is Active doesn’t show them either.

### Impact the Server as Little as Possible; Return Data as Quickly as Possible

Looking for the cause of a performance problem shouldn’t exacerbate the problem. And **taking a peek at server activity shouldn’t cause a performance problem**.

The various Microsoft monitoring procedures mentioned in yesterday’s post follow this rule quite well-they run in virtually zero time and will never impact general server performance. Unfortunately, they also provide you with virtually no useful data with which to debug issues, so you might have been better off never looking to begin with. Profiler is the opposite: it can give you lots of data with which to debug, but can also cause the entire instance to grind to a halt.

For Who is Active I’ve tried to take the middle path: provide enough data to help debug complex issues, while still working extremely hard to avoid impacting the server. In order to accomplish this I’ve disabled automatic creating of statistics on all of the temp tables, employed dirty reads to avoid having the tool block or wait for a lock to be released, used hints to control memory allocations, and use cursors (not so evil after all!) in conjunction with error handling to process certain data in a more granular fashion.

The end result is pretty good. On most servers, in most situations, the default options return all of the data in under a second. And in the (hopefully rare) cases where the server is under so much stress that things are taking longer than they should, a couple of options can be disabled to make Who is Active collect less data. Speed is especially important to me. I'm not a patient person. **And when you’re debugging a tough issue, the last thing you should have to do is wait a long time to find out what’s going on**.

### Show as Much Data as Possible Without Going Overboard

**Who is Active collects data from 15 DMVs**. Each of these DMVs has many columns. That’s a huge number of potential data points that could be displayed. I’ve pruned down this set and have tried to include only those pieces of information that are actually valuable in the vast majority of cases. I don’t want the default Who is Active output to have so many columns that it’s difficult to read and understand. And I don’t want to have to process so much data that things slow down. For this same reason, a lot of the Who is Active features are not enabled by default. If you need a bit more data, it’s usually just a matter of figuring out which parameter to set.

### Provide a Flexible and Configurable Experience

You may want the results ordered by session ID descending. I may want them ordered by the amount of time an active request has been running, ascending. You may want to see different columns than I want to see on the left, or on the right. **We both win**. Thanks to some early feedback from Aaron Bertrand, I realized that **one size does not fit all when it comes to monitoring**, and I worked to make the Who is Active procedure as flexible as it can possibly be. The various output configuration features will be covered in detail in a post this later month.

### Safety and Security

Who is Active requires slightly elevated permissions **VIEW SERVER STATE** to do its job. And most of the people who run the stored procedure are system administrators with full access to everything on the system. This would be a non-issue if the procedure contained only a simple SELECT statement or two, but for both performance and display purposes I was forced to make heavy use of dynamic SQL. **I have taken every possible precaution to avoid making the procedure vulnerable to any kind of SQL injection attack**: All inputs are not only validated, but also never directly used. All object names encoded in dynamic SQL are safely quoted using QUOTENAME. And all other variables are parameterized. Later this month I’ll describe security in a bit more detail, along with a discussion on how to properly deploy and secure access to the stored procedure.

### Version Compatibility

One of my goals at the moment is to keep Who is Active compatible with all builds of SQL Server 2005 and SQL Server 2008. I haven’t done so well here; version 10.00 included a column that wasn’t available until SQL Server 2005 SP2, and many other versions have had similar issues. I have now built a case-sensitive SQL Server 2005 RTM instance in a virtual machine, and plan to test every Who is Active build in that environment going forward.

------
Prior: [A Brief History of Activity Monitoring](01_background.md)	Next: [The License](03_license.md)
------
