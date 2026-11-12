/* Session two of the blocking scenario. Waits behind the lock that session one holds. */
SET NOCOUNT ON;
SET LOCK_TIMEOUT 120000;
BEGIN TRANSACTION;
UPDATE dbo.wia_ci_block SET v = v + 1 WHERE id = 1;
ROLLBACK TRANSACTION;
GO
