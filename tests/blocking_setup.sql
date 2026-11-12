SET NOCOUNT ON;
IF OBJECT_ID('dbo.wia_ci_block', 'U') IS NOT NULL DROP TABLE dbo.wia_ci_block;
IF OBJECT_ID('dbo.wia_ci_flag', 'U') IS NOT NULL DROP TABLE dbo.wia_ci_flag;
CREATE TABLE dbo.wia_ci_block (id int NOT NULL PRIMARY KEY, v int NOT NULL);
INSERT dbo.wia_ci_block (id, v) VALUES (1, 0);
CREATE TABLE dbo.wia_ci_flag (release int NOT NULL);
INSERT dbo.wia_ci_flag (release) VALUES (0);
GO
