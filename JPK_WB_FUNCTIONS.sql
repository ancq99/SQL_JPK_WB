USE DB_JPK_WB
GO

IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'CONVERT_MONEY')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.CONVERT_MONEY () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.CONVERT_MONEY(@d DECIMAL(19,4) )
/* format kwoty dopuszczalny w plikach JPK */
RETURNS nvarchar(20)
AS
BEGIN
	RETURN RTRIM(LTRIM(STR(@d,18,2)))
END
GO


IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'CONVERT_DATE')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.CONVERT_DATE () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.CONVERT_DATE(@d datetime )
/* format daty dopuszczalny w plikach JPK */
RETURNS nchar(10)
AS
BEGIN
	RETURN CONVERT(nchar(10), @d, 120)
END
GO

IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'GET_SALDO_POCZ')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.GET_SALDO_POCZ () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.GET_SALDO_POCZ(@od date)
--pobranie salda poczatkowego
RETURNS nvarchar(20)
AS
BEGIN
	DECLARE @saldo DECIMAL(19,4);
	SELECT TOP 1 @saldo= saldo_przed FROM WYCIAGI WHERE data >= @od
	RETURN RTRIM(LTRIM(STR(@saldo,18,2)))
END
GO


IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'GET_SALDO_KON')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.GET_SALDO_KON () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.GET_SALDO_KON(@do date)
--pobranie salda koncowego
RETURNS nvarchar(20)
AS
BEGIN
	DECLARE @saldo DECIMAL(19,4);
	SELECT TOP 1 @saldo= saldo_po FROM WYCIAGI WHERE data <= @do ORDER BY id DESC
	RETURN RTRIM(LTRIM(STR(@saldo,18,2)))
END
GO


IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'GET_ROW_NUM')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.GET_ROW_NUM () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.GET_ROW_NUM(@od date, @do date)
--pobranie ilosci rekordow w bazie
RETURNS int
AS
BEGIN
	DECLARE @num int;
	SELECT @num=COUNT(*) FROM WYCIAGI WHERE data BETWEEN @od and @do
	RETURN @num
END
GO


IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'GET_SUM_UZN')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.GET_SUM_UZN () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.GET_SUM_UZN(@od date, @do date)
--pobranie sumy uznan
RETURNS nvarchar(20)
AS
BEGIN
	DECLARE @sum DECIMAL(19,4);
	SELECT @sum=COALESCE(SUM(kwota),0) FROM WYCIAGI WHERE (typ = 1) and (data BETWEEN @od and @do)
	RETURN RTRIM(LTRIM(STR(@sum,18,2)))
END
GO



IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'GET_SUM_OBC')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.GET_SUM_OBC () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.GET_SUM_OBC(@od date, @do date)
--pobranie sumy obciazen
RETURNS nvarchar(20)
AS
BEGIN
	DECLARE @sum DECIMAL(19,4);
	SELECT @sum=COALESCE(SUM(kwota),0) FROM WYCIAGI WHERE (typ = 0) and (data BETWEEN @od and @do)
	RETURN RTRIM(LTRIM(REPLACE(STR(@sum,18,2),'-','')))
END
GO

IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'T_ZNAKOWY')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.T_ZNAKOWY () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.T_ZNAKOWY(@msg nvarchar(256) )
/* wyczyœæ pole tekstowe z wra¿liwych znaków o dlugosci 256 znakow*/
RETURNS nvarchar(256)
AS
BEGIN
	IF (@msg IS NULL)  OR (RTRIM(@msg) = N'')
		RETURN N''

	SET @msg = LTRIM(RTRIM(@msg))
	/* clear potentially dangerous characters for XML within the string */
	SET @msg = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@msg,'\n',N' '),N'<',N'?'),N'>','?'),N':',N'?'),N'\',N'?')
	SET @msg = REPLACE(@msg,N'/',N'!')

	RETURN RTRIM(LEFT(@msg,255)) 
END
GO


IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = 'NAME_TOKEN')
		AND		(o.xtype = 'FN')
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.NAME_TOKEN () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END

GO

ALTER FUNCTION dbo.NAME_TOKEN(@msg nvarchar(256) )
/* wyczyœæ pole tekstowe z wra¿liwych znaków o dlugosci 240 znakow*/
RETURNS nvarchar(240)
AS
BEGIN
	IF (@msg IS NULL)  OR (RTRIM(@msg) = N'')
		RETURN N''

	SET @msg = LTRIM(RTRIM(@msg))
	/* clear potentially dangerous characters for XML within the string */
	SET @msg = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@msg,'\n',N' '),N'<',N'?'),N'>','?'),N':',N'?'),N'\',N'?')
	SET @msg = REPLACE(@msg,N'/',N'!')

	RETURN RTRIM(LEFT(@msg,239)) 
END
GO