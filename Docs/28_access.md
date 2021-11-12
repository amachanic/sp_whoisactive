# sp_whoisactive: Access for All!

------
[Home](https://github.com/amachanic/sp_whoisactive)	[Download](https://github.com/amachanic/sp_whoisactive/archive/master.zip)	[Documentation Index](ReadMe.md)
------
Prior: [Who is Active's Hidden Gems](27_gems.md)
------

A prior article discussed [basic security requirements](04_installation.md) for Who is Active. I mentioned the VIEW SERVER STATE permission and the fact that I consider it to be “a relatively low barrier to entry.”

But what if, in your organization, it’s not? **Auditing requirements being what they are, you might be required to lock things down**. And granting someone full and unrestricted VIEW SERVER STATE may simply not be an option.

**Enter module signing**. By securing Who is Active (or any other securable, for that matter) via inherited permissions, it’s often possible to get around auditing requirements, as long as the module itself has been reviewed. This is not at all a difficult thing to do, but in my experience most DBAs haven’t played much with signed modules. Today I’ll show you how quick and easy it can be to set things up.

#### Start by creating a certificate.

```sql
USE master
GO

CREATE CERTIFICATE WhoIsActive_Permissions
ENCRYPTION BY PASSWORD = '1bigHUGEpwd4WhoIsActive!'
WITH SUBJECT = 'Who is Active',
EXPIRY_DATE = '9999-12-31'
GO
```

Once you have a certificate in place, you can create a login from the certificate. The goal is to grant permissions, and to do that you need a principal with which to work; a certificate does not count. A login based on the certificate uses the certificate’s cryptographic thumbprint as its identifier. These logins are sometimes referred to as “loginless logins,” but [I refer to them as “proxy logins”](http://dataeducation.com/creating-proxies-in-sql-server/) since that’s what they’re used for: proxies for the sake of granting permissions.

```sql
CREATE LOGIN WhoIsActive_Login
FROM CERTIFICATE WhoIsActive_Permissions
GO
```

The login can be granted any permission that can be granted to a normal login. For example, VIEW SERVER STATE:

```sql
GRANT VIEW SERVER STATE
TO WhoIsActive_Login
GO
```

Once the permission has been granted, the certificate can be used to sign the module—in this case, Who is Active. When the procedure is executed, a check will be made to find associated signatures. The thumbprint of the certificates and/or keys used to sign the module will be checked for associated logins, and any permissions granted to the logins will be available within the scope of the module—meaning that the caller will temporarily gain access.

```sql
ADD SIGNATURE TO sp_WhoIsActive
BY CERTIFICATE WhoIsActive_Permissions
WITH PASSWORD = '1bigHUGEpwd4WhoIsActive!'
GO
```

**Getting to this step will be enough to allow anyone with EXECUTE permission on Who is Active to exercise most of its functionality**. There are a couple of notes and caveats: First of all, every time you ALTER the procedure (such as when upgrading to a new version), the signature will be dropped and the procedure will have to be re-signed. You won’t have to create the certificate or the login again; you’ll just have to re-run that final statement. Second, you’ll only be able to use *most* of the functionality. Certain features, such as blocked object resolution mode, won’t operate properly, depending on whether the caller has access to the database in which the block is occurring. This may or may not be a problem—it depends on your environment and what users need to see—and Who is Active itself won’t throw an exception. An error message will be returned somewhere in the results, depending on what the user has tried to do.

If you would like to grant database-level permissions based on the certificate login so as to avoid these errors, that’s doable to. Just do something like:

```sql
USE AdventureWorks
GO

CREATE USER WhoIsActive_User
FOR LOGIN WhoIsActive_Login
GO

EXEC sp_addrolemember
  'db_datareader',
  'whoisactive_user'
GO
```

This will allow Who is Active to figure out what the various blocked or locked object names are. Since the login is just a proxy no one can actually log in and get direct access to read the data, so this isn’t something I consider to be a security risk. However, keep in mind that if anyone has the password for the certificate and sufficient privileges in *master*, a new module could be created and signed. Keep the password secure, and make sure to carefully audit to catch any infractions before they become a risk.

------
Prior: [Who is Active's Hidden Gems](27_gems.md)
------
