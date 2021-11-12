# sp_whoisactive: Who is Active's Hidden Gems

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [Delta Force](26_delta.md)	Next: [Access for All!](28_access.md)
------

A few things that I’ve added to sp_whoisactive along the way have been especially useful, but there hasn’t been a good place to feature them in the articles.

#### Always Show Blockers

In [a prior article](09_deciding.md) I talked about filters. Filters let you decide exactly what you want to see, and what you not don’t want to see (“not” filters). But sometimes you have no choice: if you’re filtering so that you only see session 123, and it’s being blocked by session 456, you’ll also see information about session 456. The idea is that you should *always* get enough context to fully evaluate the problem at hand. Even if it means that you see more information than you were intending to see the first time around. You probably would have asked for 456 next anyway.

#### “RUNNABLE” Waits

In *@get_task_info = 2* mode, you may see waits called “RUNNABLE.” This could strike you as an oddity, given that *there is no such wait type* in SQL Server. I wanted to show [tasks on the runnable queue](13_queries.md), and making up a fake wait type seemed like a reasonable way of accomplishing the task. In practice, it has worked extremely well—I’ve used this feature countless times to help understand scheduler contention on a SQL Server instance.

#### Accurate CPU Time Deltas

CPU time is a tricky metric. It gets handled by Who is Active’s [delta mode](26_delta.md), and has for several versions. But historically, never very well. The data [simply isn’t represented in an easily-obtainable fashion](02_design.md) in the core DMVs. Recently I decided to dig deeper into this problem and discovered that I could get better numbers from some of the thread-specific DMVs. They’re cumulative numbers, based on the lifetime of the entire thread—not too good for the usual Who is Active output. But for snapshot and delta purposes, just about perfect. Meaning that in v11.00 of Who is Active, you can see the [CPU] column show a value of 0, while the [CPU_delta] column shows a value in the thousands. It’s not a bug. It’s a feature. (It really is!)

#### Text Query Plans and the XML Demon

SQL Server 2005 introduced query plans as XML. Management Studio knew how to render these plans graphically. And we were able to pull the plans from DMVs. Life was great. Except, perhaps, when you actually wanted to view one of these plans, and you had to save the thing out to a .SQLPLAN file, close the file, then re-open it. That’s about three steps too many for my taste, so I was overjoyed when the Management Studio team decided to wire things up the right way in SQL Server 2008. Click on a showplan XML document, see a graphical plan. Simple as that.

Unfortunately, the XML data type has its own issues, including one particularly nasty arbitrary limitation that has to do with nesting depth. The idea is to make sure that XML indexes don’t crash and burn too often (not a big concern for me, given that I’ve never seen one used in a production environment—but I digress). The problem is that query plans are heavily nested. And to get that nice graphical plan workflow, SSMS needs the plan rendered as XML.

In prior versions of Who is Active I gave up and returned either an error or a NULL. But in v11.00 I decided to make things a bit better. If the nesting issue occurs, Who is Active will now return the plan as XML encapsulated in some other XML in a text format, along with instructions on how to view the plan. This won’t give you a nice one-click experience, but it will give you the ability to use Who is Active to see some of the bigger plans that are causing performance issues.

#### Service Broker Needs Love Too

One of the most interesting features of Service Broker is activation. But a vexing design choice on behalf of the Service Broker team was to make activation procedures launch as system sessions. This means, among other things, that prior versions of Who is Active filtered them right out of the default view. To see them you’d have to enable *@show_system_spids*. And then you’d have to ignore all of the other system stuff. And you’d get woefully bad time information (no, the activation process hasn’t been running for 25 days; that’s the last time you restarted the SQL Server instance). In Who is Active v11.00 this has been fixed. Service Broker activation processes are now displayed by default along with other user activity. And I found a way to fix the timing issue, thanks to some advice on Twitter from Remus Rusanu, one of the guys who originally worked on Service Broker. So if you’re using activation and monitoring with Who is Active, life is good.

------
Prior: [Delta Force](26_delta.md)	Next: [Access for All!](28_access.md)
------
