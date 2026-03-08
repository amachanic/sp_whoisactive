# sp_WhoIsActive
[![licence badge]][licence]
[![stars badge]][stars]
[![forks badge]][forks]
[![issues badge]][issues]

`sp_WhoIsActive` is a comprehensive activity monitoring stored procedure that works for all versions of SQL Server from 2005 through 2022 and Azure SQL DB.

`sp_WhoIsActive` is now officially versioned and maintained here on GitHub.

The license is now [GPLv3](/LICENSE).

Documentation is still available at http://whoisactive.com/docs

If you have enhancements, please consider a PR instead of a fork. I would like to continue to maintain this project for the community.

# Installation instructions

Download the script [sp_WhoIsActive.sql](sp_WhoIsActive.sql) from this root folder, open it in SQL Server Management Studio, and run it!

> [!TIP]
> The script will run in the database of the current connected session.  
> If you want, you can change the database to master so the procedure will be available to run from every database in the instance.


## Previous version compatibility

The script root folder is focused on supporting the latest SQL Server release features and compatibility.
To use it with older versions, do the following:

- For 2012 to 2019, use the [sp_WhoIsActive.sql from the 2019 folder](2019/sp_WhoIsActive.sql)
- For 2008 or earlier, use the [sp_WhoIsActive.sql from the 2008 folder](2008/sp_WhoIsActive.sql)


[licence badge]:https://img.shields.io/badge/license-GPLv3-blue.svg
[stars badge]:https://img.shields.io/github/stars/amachanic/sp_whoisactive.svg
[forks badge]:https://img.shields.io/github/forks/amachanic/sp_whoisactive.svg
[issues badge]:https://img.shields.io/github/issues/amachanic/sp_whoisactive.svg

[licence]:https://github.com/amachanic/sp_whoisactive/blob/master/LICENSE
[stars]:https://github.com/amachanic/sp_whoisactive/stargazers
[forks]:https://github.com/amachanic/sp_whoisactive/network
[issues]:https://github.com/amachanic/sp_whoisactive/issues
