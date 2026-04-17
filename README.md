# sp_WhoIsActive
[![licence badge]][licence]
[![stars badge]][stars]
[![forks badge]][forks]
[![issues badge]][issues]

`sp_WhoIsActive` is a comprehensive activity monitoring stored procedure that works for all versions of SQL Server from 2005 through 2022 and Azure SQL DB.

`sp_WhoIsActive` is now officially versioned and maintained here on GitHub.

The license is now [GPLv3](/LICENSE).

[GitHub Documentation](/Docs/ReadMe.md)

Documentation is also available at http://whoisactive.com/docs

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

Going forward new folders will be created every two versions, so that the script can continue to grow and mature with SQL Server.

## Script version numbering

Version numbering indicates the minimum and maximum supported versions, and the release date, in the following format:
vAABB.YYYYMMDD

AA and BB represent minimum and maximum supported SQL Server release years in the 2000s. YYYYMMDD is the date of the sp_whoisactive release.

So v1219.20260419 means the script that targets SQL Server 2012-2019, with a release date of 2026-04-19.

The current version will always have a 00 for the BB portion, indicating its support for some number of future versions. (Ideally one to two, as noted in the previous version compatibility section.)

[licence badge]:https://img.shields.io/badge/license-GPLv3-blue.svg
[stars badge]:https://img.shields.io/github/stars/amachanic/sp_whoisactive.svg
[forks badge]:https://img.shields.io/github/forks/amachanic/sp_whoisactive.svg
[issues badge]:https://img.shields.io/github/issues/amachanic/sp_whoisactive.svg

[licence]:https://github.com/amachanic/sp_whoisactive/blob/master/LICENSE
[stars]:https://github.com/amachanic/sp_whoisactive/stargazers
[forks]:https://github.com/amachanic/sp_whoisactive/network
[issues]:https://github.com/amachanic/sp_whoisactive/issues
