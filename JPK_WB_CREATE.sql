USE DB_JPK_WB
GO

-- tabele: podmioty (id, NIP, nazwa, REGON, adres), adresy, wyciagi

/*
	DROP TABLE WYCIAGI
	DROP TABLE LOGI
	DROP TABLE PODMIOTY
	DROP TABLE ADRESY
*/

--tabela docelowa adresy, opsije adres podmiotu
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'ADRESY')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.ADRESY
	(	id					int				NOT NULL IDENTITY CONSTRAINT PK_ADRESY PRIMARY KEY	 
	,	kod_kraju			nvarchar(2)		NOT NULL DEFAULT 'PL'
	,	wojewodztwo			nvarchar(50)	NOT NULL
	,	powiat				nvarchar(50)	NOT NULL
	,	gmina				nvarchar(50)	NOT NULL
	,	ulica				nvarchar(50)	NOT NULL
	,	nr_domu				nvarchar(50)	NOT NULL
	,	nr_lokalu			nvarchar(50)	NOT	NULL DEFAULT ''
	,	miejscowosc			nvarchar(50)	NOT NULL
	,	kod_pocztowy		nvarchar(6)		NOT NULL
	,	poczta				nvarchar(50)	NOT NULL
	)

END
GO

--tabela docelowa pomioty, opsije podmiot
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'PODMIOTY')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.PODMIOTY
	(	id			int				NOT NULL IDENTITY CONSTRAINT PK_PODMIOTY PRIMARY KEY	 
	,	NIP			nvarchar(10)	NOT NULL UNIQUE
	,	nazwa		nvarchar(100)	NOT NULL
	,	REGON		nvarchar(9)		NULL
	,   IBAN		nvarchar(30)	NOT NULL UNIQUE
	,	kod_urzedu	nvarchar(4)		NOT NULL 
	,	adres		int				NOT NULL CONSTRAINT FK_PODMIOT_ADRES REFERENCES adresy(id)

	)

END
GO

--tabela docelowa wyciagi, opsije transakcje bankowe
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'WYCIAGI')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.WYCIAGI
	(	id			int				NOT NULL IDENTITY CONSTRAINT PK_WYCIAGI PRIMARY KEY	 
	,   id_klienta	int				NOT NULL CONSTRAINT FK_WYCIAG_PODMIOT REFERENCES PODMIOTY(id)
	,	data		DATE			NOT NULL
	,	nazwa		nvarchar(100)	NOT NULL
	,	opis		nvarchar(100)	NOT NULL
	,	kwota		DECIMAL(19,4)	NOT NULL
	,	typ			BIT				NOT NULL -- 1 - uznanie, 0 - obciazenie
	,	saldo_po	DECIMAL(19,4)	NOT NULL
	,	saldo_przed	DECIMAL(19,4)	NOT NULL
	)

END
GO

--tabela logi, opsije hisorie logow
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'LOGI')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE dbo.LOGI
	(	id			int				NOT NULL IDENTITY CONSTRAINT PK_LOGI PRIMARY KEY	 
	,	kto 		int				NULL	 CONSTRAINT FK_LOG_PODMIOT REFERENCES PODMIOTY(id)
	,	opis		nvarchar(100)	NOT NULL
	,	kiedy		DATETIME		NOT NULL DEFAULT GETDATE()
	,	typ			BIT				NOT NULL -- 1 - blad, 0 - info
	)

END
GO


-- TEMP Tables
--DROP TABLE FILE_1_TMP
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'FILE_1_TMP')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE FILE_1_TMP (
			NIP					nvarchar(10)	NOT NULL UNIQUE
		,	nazwa				nvarchar(100)	NOT NULL
		,	REGON				nvarchar(9)		NULL
		,   IBAN				nvarchar(30)	NOT NULL UNIQUE
		,	kod_urzedu			nvarchar(4)		NOT NULL 
		,	kod_kraju			nvarchar(2)		NOT NULL DEFAULT 'PL'
		,	wojewodztwo			varchar(50)		NOT NULL
		,	powiat				nvarchar(50)	NOT NULL
		,	gmina				nvarchar(50)	NOT NULL
		,	ulica				nvarchar(50)	NOT NULL
		,	nr_domu				nvarchar(50)	NOT NULL
		,	nr_lokalu			nvarchar(50)	NOT	NULL DEFAULT ''
		,	miejscowosc			nvarchar(50)	NOT NULL
		,	kod_pocztowy		nvarchar(6)		NOT NULL
		,	poczta				nvarchar(50)	NOT NULL
		)
END
GO

--Drop table FILE_2_TMP
IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'FILE_2_TMP')
		AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable')=1)
)
BEGIN
	CREATE TABLE FILE_2_TMP (
			IBAN				nvarchar(30)	NOT NULL
		,	Saldo_przed			DECIMAL(19,4)	NOT NULL
		,	data				nvarchar(50)	NOT NULL
		,	kontrahent			nvarchar(50)	NOT NULL
		,   opis				nvarchar(250)	NOT NULL
		,	kwota				DECIMAL(19,4)	NOT NULL 
		,	Saldo_po			DECIMAL(19,4)	NOT NULL 
		)
END
GO

--Select * FROM FILE_1_TMP
--Select * FROM FILE_2_TMP



