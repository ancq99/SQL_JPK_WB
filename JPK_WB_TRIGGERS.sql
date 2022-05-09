USE DB_JPK_WB
GO

-- FILE 1 trigger, uruchamia sie w trakcie dodania rekordow i laduje dane do tabel docelowych 
IF EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'TRIGGER_INSERT_FILE_1')
		AND		[type] = 'TR'
		)

BEGIN
	DROP TRIGGER TRIGGER_INSERT_FILE_1
END
GO


CREATE TRIGGER TRIGGER_INSERT_FILE_1
	ON dbo.FILE_1_TMP
	AFTER INSERT
	AS
BEGIN
	DECLARE 
		@NIP				nvarchar(10)
	,	@nazwa				nvarchar(50)
	,	@REGON				nvarchar(9)
	,	@IBAN				nvarchar(30)
	,	@kod_urzedu			nvarchar(4)
	,	@wojewodztwo		nvarchar(50)
	,	@powiat				nvarchar(50)	
	,	@gmina				nvarchar(50)	
	,	@ulica				nvarchar(50)	
	,	@nr_domu			nvarchar(50)	
	,	@nr_lokalu			nvarchar(50)	
	,	@miejscowosc		nvarchar(50)	
	,	@kod_pocztowy		nvarchar(6)		
	,	@poczta				nvarchar(50);
	
	SELECT --pobranie danych z tabeli tymczasowej
		@NIP = NIP,
		@nazwa = nazwa,
		@REGON = REGON,
		@IBAN = IBAN,
		@kod_urzedu = kod_urzedu,
		@wojewodztwo = wojewodztwo,
		@powiat = powiat,
		@gmina = gmina,
		@ulica = ulica,
		@nr_domu = nr_domu,
		@nr_lokalu = nr_lokalu,
		@miejscowosc = miejscowosc,
		@kod_pocztowy = kod_pocztowy,
		@poczta = poczta

	FROM dbo.FILE_1_TMP


	IF NOT EXISTS --sprawdzenie czy podmiot juz wystepuje w bazie
	(	SELECT 1 
		from dbo.PODMIOTY
		WHERE NIP = @NIP and IBAN = @IBAN
		)
	BEGIN
		--najpierw dodajemy adres 
		INSERT INTO dbo.ADRESY 
			(wojewodztwo, powiat, gmina, ulica, nr_domu, nr_lokalu, miejscowosc, kod_pocztowy, poczta)
		Values
			(@wojewodztwo, @powiat, @gmina, @ulica, @nr_domu, @nr_lokalu, @miejscowosc, @kod_pocztowy, @poczta)

		--klucz glowny dodanego adresu
		declare @id int 
		select @id = Scope_Identity()

		--dodanie podmiotu do tabeli
		INSERT INTO dbo.PODMIOTY
			(NIP, nazwa, REGON, IBAN, kod_urzedu, adres)
		VALUES 
			(@NIP, @nazwa, @REGON, @IBAN, @kod_urzedu, @id)

		--klucz glowny ostatniego dodanego podmiotu
		select @id = Scope_Identity()

		--dodanie do logow
		INSERT INTO dbo.LOGI
			(kto, opis, kiedy, typ)
		VALUES
			(@id, 'Dodanie nowego podmiotu '+@IBAN+' do bazy', SYSDATETIME(), 0)
	END
	ELSE
	BEGIN
		INSERT INTO dbo.LOGI
			(kto, opis, kiedy, typ)
		VALUES
			(@id, 'Proba dodania pomiotu ('+@IBAN+') juz wystepujacego w bazie', SYSDATETIME(), 1)
	END
	
	
END
GO

/* sprawdzenie
SELECT * FROM LOGI
SELECT * FROM ADRESY
SELECT * FROM PODMIOTY
*/

-- FILE 2 trigger uruchamia sie po dodaniu rekordow do tabeli tymaczoswej

IF EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = N'TRIGGER_INSERT_FILE_2')
		AND		[type] = 'TR'
		)

BEGIN
	DROP TRIGGER TRIGGER_INSERT_FILE_2
END
GO


CREATE TRIGGER TRIGGER_INSERT_FILE_2
	ON dbo.FILE_2_TMP
	AFTER INSERT
	AS
BEGIN
	DECLARE 
		@saldo_przed		DECIMAL(19,4)
	,	@data				DATETIME
	,	@kontrahent			nvarchar(50)
	,	@opis				nvarchar(250)
	,	@kwota				DECIMAL(19,4)
	,	@typ				bit
	,	@saldo_po			DECIMAL(19,4)
	,	@IBAN				nvarchar(30)
	,	@id					int
	,	@saldo_check1		DECIMAL(19,4)
	,	@saldo_check2		DECIMAL(19,4)
	,	@IBAN_check1		nvarchar(30)
	,	@IBAN_check2		nvarchar(30);
	
	--sprawdzenei czy dane z tego samego rachunku
	SELECT @IBAN_check1=IBAN FROM dbo.PODMIOTY WHERE id = (SELECT TOP 1 id FROM dbo.WYCIAGI) 
	SELECT TOP 1 @IBAN_check2=IBAN FROM dbo.FILE_2_TMP

	--sprawdzenie zgodnosci sald
	SELECT TOP 1 @saldo_check1 = saldo_przed FROM dbo.FILE_2_TMP 
	SELECT TOP 1 @saldo_check2 = saldo_po FROM dbo.WYCIAGI ORDER BY id DESC

	IF NOT @saldo_check1 = @saldo_check2 or NOT @IBAN_check1 LIKE @IBAN_check2 --sprawdzenie czy kontynuacja poprzedniego pliku
	BEGIN
		INSERT INTO LOGI VALUES((SELECT TOP 1 id FROM dbo.WYCIAGI), 'Czyszczenie tabeli wyciagi', SYSDATETIME(), 0)
		TRUNCATE TABLE dbo.WYCIAGI
	END

	-- dodanie wartosci poprzez petle
	DECLARE cursor_trigger INSENSITIVE CURSOR
	FOR
		SELECT * FROM dbo.FILE_2_TMP

	OPEN cursor_trigger;

	FETCH NEXT FROM cursor_trigger INTO @IBAN, @saldo_przed, @data, @kontrahent, @opis, @kwota, @saldo_po
	WHILE @@FETCH_STATUS = 0
		BEGIN
			if CHARINDEX('-',@kwota) > 0 --ustalenie czy uznanie czy obciazenie
			begin
				SET @typ = 0
			end
			else
			begin
				SET @typ = 1
			end

			SELECT @id=id FROM dbo.PODMIOTY WHERE IBAN LIKE @IBAN --pobranie id podmiotu

			INSERT INTO dbo.WYCIAGI 
				(id_klienta, data, nazwa, opis, kwota, typ, saldo_po, saldo_przed)
			VALUES
				(@id, @data, @kontrahent, @opis, @kwota, @typ, @saldo_po, @saldo_przed)

			

		FETCH NEXT FROM cursor_trigger INTO @IBAN, @saldo_przed, @data, @kontrahent, @opis, @kwota, @saldo_po
		END
	CLOSE cursor_trigger
	DEALLOCATE cursor_trigger

	INSERT INTO LOGI VALUES(@id, 'Dodanie rekordow wyciagu bankowego dla'+@IBAN, SYSDATETIME(), 0)

END


/*
SELECT * FROM dbo.PODMIOTY
SELECT * FROM dbo.ADRESY
SELECT * FROM dbo.WYCIAGI
SELECT * FROM dbo.LOGI
*/