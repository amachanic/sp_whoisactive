/*
Session one of the blocking scenario. Takes an exclusive row lock, then waits
until the release flag is set. The loop is capped at 120 seconds so a broken
test run cannot leave the session behind for long.
*/
SET NOCOUNT ON;
BEGIN TRANSACTION;
UPDATE dbo.wia_ci_block SET v = v + 1 WHERE id = 1;

DECLARE @i int = 0;
WHILE @i < 120 AND (SELECT release FROM dbo.wia_ci_flag) = 0
BEGIN
    WAITFOR DELAY '00:00:01';
    SET @i += 1;
END;

ROLLBACK TRANSACTION;
GO
