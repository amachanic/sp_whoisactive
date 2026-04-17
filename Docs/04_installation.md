# sp_whoisactive: Installing sp_whoisactive

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [The License](03_license.md)	Next: [Less Data is More Data](05_lessdata.md)
------

An entire post on installation? Isn’t Who is Active just a stored procedure..?
Well, yes. And yes. It might be as easy as [downloading the .ZIP file](https://github.com/amachanic/sp_whoisactive/archive/master.zip), unzipping it, opening the .SQL file in Management Studio, and hitting F5 or CTRL-E.

But if you’re like some of the people who’ve e-mailed me over the past few years, you may have some questions...
 
### What Permissions Are Required?

Most of what Who is Active does requires **VIEW SERVER STATE** permission. This is a permission level that allows access to the various instance-global DMVs, including the request, session, and transaction related views. In most cases there is no reason to avoid granting this privilege to a user; the main concern is situations where a user might be able to harvest private information by looking at SQL text, especially when it is non-parameterized. These cases being quite few and far between, I consider this to be a relatively low barrier to entry.

Beyond **VIEW SERVER STATE**, various other **Who is Active features may require access to specific databases**. The most important of these features are locks collection and blocked object name resolution (both of which will be covered in a subsequent post). When these are used, the stored procedure will attempt to access the database in which the lock or blocking is occurring, in order to resolve the affected object names. If the user calling Who is Active does not have sufficient privileges in the database, Who is Active will collect the error message and report it instead of the object name.

### Which Database Should I Put it In?

The stored procedure is named “**sp_WhoIsActive**” for a reason: It’s designed to live in the master database; the “**sp_**” prefix, as you’re probably aware, allows a stored procedure in master to be called from the context of any database on the instance.

I know that many DBAs like to keep all of the DBA scripts in a special-purpose DBA database. Who is Active will work fine from there. But really, it’s much nicer to keep it in master. **Never underestimate the power of convenience**.

### Help! It Keeps Throwing the Error: “Incorrect syntax near '.'”

It’s amazing how many times people have written and asked me about this particular error. Not because it’s obvious what’s going on, but because of what it means: You’ve upgraded to SQL Server 2005 or SQL Server 2008 from SQL Server 2000, and **you haven’t updated the database compatibility level**. This error is thrown when a database in SQL Server 2000 compatibility mode encounters a common table expression. It’s not pretty, and it doesn’t need to happen.

Stop reading this right now and go run the following query against your production SQL Server 2005 or 2008 instances:

```sql
SELECT *
FROM sys.databases
WHERE
    compatibility_level < 100
```

If any rows are returned, think long and hard about why that database needs to be set so as to make your life more difficult. And then update the compatibility level to something that makes sense in 2020, not 1998.

### Help! It’s Throwing Some Other Error!

If Who is Active is throwing some error aside from the one above, and it’s not a permissions-related issue, then it’s probably my fault. **create an issue in [GitHub](https://github.com/amachanic/sp_whoisactive/issues), so that I can start working on the problem.** If there is a problem, I want to fix it. And trust me when I say that I take problems with Who is Active very seriously. Most of the features and bug fixes are the result of users telling me what does and does not work for them. I can’t stress enough how much I enjoy both getting, and acting on, your feedback.

------
Prior: [The License](03_license.md)	Next: [Less Data is More Data](05_lessdata.md)
------
