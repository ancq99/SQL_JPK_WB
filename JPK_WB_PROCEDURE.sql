USE DB_JPK_WB
GO

IF NOT EXISTS 
(	SELECT 1 
		from sysobjects o (NOLOCK)
		WHERE	(o.[name] = 'GEN_JPK')
		AND		(OBJECTPROPERTY(o.[ID],'IsProcedure')=1)
)
BEGIN
	DECLARE @stmt nvarchar(100)
	SET @stmt = 'CREATE PROCEDURE dbo.GEN_JPK AS '
	EXEC sp_sqlexec @stmt
END
GO


-- procedura generujaca plik jpk_wb
ALTER PROCEDURE dbo.GEN_JPK @od nvarchar(100)=NULL, @do nvarchar(100)=NULL, @path nvarchar(100)
AS
	IF @od is NULL
	BEGIN
		SELECT @od = MIN(data) FROM dbo.WYCIAGI
	END

	IF @do is NULL
	BEGIN
		SELECT @do = MAX(data) FROM dbo.WYCIAGI
	END



	DECLARE @xml xml,
			@id int;

	SELECT TOP 1 @id = id_klienta FROM WYCIAGI --pobranie klucza glownego klienta

	 SET @xml = null

		;WITH XMLNAMESPACES(N'http://jpk.mf.gov.pl/wzor/2019/09/27/09271/'      AS tns
			, N'http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/' AS etd)
		
    select @xml = 
		( SELECT --naglowek
				(
				SELECT
				  N'1-0'						AS [tns:KodFormularza/@wersjaSchemy]					
				, N'JPK_WB'						AS [tns:KodFormularza/@kodSystemowy]					
				, N'JPK_WB'                     AS [tns:KodFormularza]                                  
				, N'1'                          AS [tns:WariantFormularza]                              
				, N'1'                          AS [tns:CelZlozenia]                                    
				, GETDATE()                     AS [tns:DataWytworzeniaJPK]                             
				, dbo.CONVERT_DATE(@od)			AS [tns:DataOd]                                         
				, dbo.CONVERT_DATE(@do)			AS [tns:DataDo]                                         
				, s.kod_urzedu					AS [tns:KodUrzedu]										

					FROM dbo.PODMIOTY (NOLOCK) s WHERE s.id = @id

				FOR XML PATH('tns:Naglowek'), TYPE)
		,
        (SELECT
                (
				SELECT  --identyfikator podmiotu
					s.NIP						AS [etd:NIP]
                  , dbo.NAME_TOKEN(nazwa)		AS [etd:PelnaNazwa] 
				  , s.REGON						AS [etd:REGON]

                        FROM dbo.PODMIOTY (NOLOCK) s WHERE s.id = @id
                        FOR XML PATH('tns:IdentyfikatorPodmiotu'), TYPE
                )
                ,
                (
				SELECT	-- adres podmiotu
								N'PL'				AS [etd:KodKraju]
                        ,       s.Wojewodztwo       AS [etd:Wojewodztwo]
                        ,       s.Powiat            AS [etd:Powiat]
                        ,       s.gmina             AS [etd:Gmina]
                        ,       s.Ulica             AS [etd:Ulica]
                        ,       s.nr_domu 			AS [etd:NrDomu]
                        ,       s.nr_lokalu			AS [etd:NrLokalu]
                        ,       s.Miejscowosc		AS [etd:Miejscowosc]
                        ,       s.kod_pocztowy		AS [etd:KodPocztowy]
						,       s.poczta            AS [etd:Poczta] 

                                FROM dbo.ADRESY (NOLOCK) s WHERE s.id = (SELECT adres FROM dbo.PODMIOTY WHERE id = @id)

                        FOR XML PATH('tns:AdresPodmiotu'), TYPE
                )
				FOR XML PATH('tns:Podmiot1'), TYPE
				)
		, 
		( SELECT
				(
				SELECT	--numer IBAN
					s.IBAN						AS [tns:NumerRachunku]	
				
					FROM dbo.PODMIOTY (NOLOCK) s WHERE s.id = @id

				FOR XML PATH('tns:NumerRachunku'), TYPE)
		)
		,
		( SELECT
				(
				SELECT --salda
				  dbo.GET_SALDO_POCZ (@od)				AS [tns:SaldoPoczatkowe]					
				, dbo.GET_SALDO_KON	(@do)				AS [tns:SaldoKoncowe]				
				
				FOR XML PATH('tns:Salda'), TYPE)
		)
		,
		( SELECT
				(
				SELECT --historia transakcji
				  RANK() OVER (ORDER BY s.id)		AS [tns:NumerWiersza]					
				, dbo.CONVERT_DATE(s.data)			AS [tns:DataOperacji]
				, dbo.T_ZNAKOWY(s.nazwa)			AS [tns:NazwaPodmiotu] 
				, dbo.T_ZNAKOWY(s.opis)				AS [tns:OpisOperacji] 
				, dbo.CONVERT_MONEY(s.kwota)		AS [tns:KwotaOperacji]
				, dbo.CONVERT_MONEY(s.saldo_po)		AS [tns:SaldoOperacji]

					FROM WYCIAGI (NOLOCK) s WHERE data BETWEEN @od and @do 
				FOR XML PATH('tns:WyciagWiersz'), TYPE)

		)
		,
		( SELECT
				(
				SELECT --wyciag kontrolny
				  dbo.GET_ROW_NUM (@od, @do)			AS [tns:LiczbaWierszy]					
				, dbo.GET_SUM_OBC (@od, @do)			AS [tns:SumaObciazen]
				, dbo.GET_SUM_UZN (@od, @do)			AS [tns:SumaUznan]
				
				FOR XML PATH('tns:WyciagCtrl'), TYPE)

		)
		FOR XML PATH(''), TYPE, ROOT('tns:JPK')
        )

		SET @xml.modify('declare namespace tns = "http://jpk.mf.gov.pl/wzor/2019/09/27/09271/"; insert attribute xsi:schemaLocation{"http://jpk.mf.gov.pl/wzor/2019/09/27/09271/ schema.xsd"} as last into (tns:JPK)[1]')


		INSERT INTO LOGI VALUES(@id, 'Wygenerowanie pliku JPK_WB', SYSDATETIME(), 0)

		--tabela tymczasowa potrzebna do zapisu xml na dysku
		DROP TABLE IF EXISTS ##TEMP_TABLE
		SELECT @xml as xml INTO ##TEMP_TABLE

		--SELECT * FROM ##TEMP_TABLE

		DECLARE @sql nvarchar(500)
		SET @sql = 'bcp "SELECT xml FROM ##TEMP_TABLE" queryout "'+@path+'JPK_WB.xml" -T -c -t,'
		
		EXEC xp_cmdshell @sql

 GO

 /*
 zmiany konfigu serwera w celu umozlienia zapisu przez xp_cmdshell
 EXEC master.dbo.sp_configure 'show advanced options', 1
RECONFIGURE
EXEC master.dbo.sp_configure 'xp_cmdshell', 1
RECONFIGURE
*/

 EXEC dbo.GEN_JPK @path='C:\tmp\'

 /*
 <tns:JPK
	xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
	xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/"
	xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/ schema.xsd">
	<tns:Naglowek
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:KodFormularza wersjaSchemy="1-0" kodSystemowy="JPK_WB">JPK_WB</tns:KodFormularza>
		<tns:WariantFormularza>1</tns:WariantFormularza>
		<tns:CelZlozenia>1</tns:CelZlozenia>
		<tns:DataWytworzeniaJPK>2022-05-07T15:25:17.920</tns:DataWytworzeniaJPK>
		<tns:DataOd>2022-02-10</tns:DataOd>
		<tns:DataDo>2022-02-12</tns:DataDo>
		<tns:KodUrzedu>0202</tns:KodUrzedu>
	</tns:Naglowek>
	<tns:Podmiot1
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:IdentyfikatorPodmiotu
			xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
			xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
			<etd:NIP>4058195881</etd:NIP>
			<etd:PelnaNazwa>podmiot1</etd:PelnaNazwa>
			<etd:REGON>137318807</etd:REGON>
		</tns:IdentyfikatorPodmiotu>
		<tns:AdresPodmiotu
			xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
			xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
			<etd:KodKraju>PL</etd:KodKraju>
			<etd:Wojewodztwo>slaskie</etd:Wojewodztwo>
			<etd:Powiat>lubliniecki</etd:Powiat>
			<etd:Gmina>lubliniec</etd:Gmina>
			<etd:Ulica>lipowa</etd:Ulica>
			<etd:NrDomu>14</etd:NrDomu>
			<etd:NrLokalu/>
			<etd:Miejscowosc>lubliniec</etd:Miejscowosc>
			<etd:KodPocztowy>42-700</etd:KodPocztowy>
			<etd:Poczta>lubliniec</etd:Poczta>
		</tns:AdresPodmiotu>
	</tns:Podmiot1>
	<tns:NumerRachunku
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:NumerRachunku>PL25109024028713951641489122</tns:NumerRachunku>
	</tns:NumerRachunku>
	<tns:Salda
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:SaldoPoczatkowe>125.00</tns:SaldoPoczatkowe>
		<tns:SaldoKoncowe>123.00</tns:SaldoKoncowe>
	</tns:Salda>
	<tns:WyciagWiersz
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:NumerWiersza>1</tns:NumerWiersza>
		<tns:DataOperacji>2022-02-10</tns:DataOperacji>
		<tns:NazwaPodmiotu>aaaa</tns:NazwaPodmiotu>
		<tns:OpisOperacji>piwo</tns:OpisOperacji>
		<tns:KwotaOperacji>38.00</tns:KwotaOperacji>
		<tns:SaldoOperacji>163.00</tns:SaldoOperacji>
	</tns:WyciagWiersz>
	<tns:WyciagWiersz
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:NumerWiersza>2</tns:NumerWiersza>
		<tns:DataOperacji>2022-02-10</tns:DataOperacji>
		<tns:NazwaPodmiotu>bbbb</tns:NazwaPodmiotu>
		<tns:OpisOperacji>sushi</tns:OpisOperacji>
		<tns:KwotaOperacji>100.00</tns:KwotaOperacji>
		<tns:SaldoOperacji>263.00</tns:SaldoOperacji>
	</tns:WyciagWiersz>
	<tns:WyciagWiersz
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:NumerWiersza>3</tns:NumerWiersza>
		<tns:DataOperacji>2022-02-11</tns:DataOperacji>
		<tns:NazwaPodmiotu>eeee</tns:NazwaPodmiotu>
		<tns:OpisOperacji>burgery</tns:OpisOperacji>
		<tns:KwotaOperacji>-22.00</tns:KwotaOperacji>
		<tns:SaldoOperacji>241.00</tns:SaldoOperacji>
	</tns:WyciagWiersz>
	<tns:WyciagWiersz
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:NumerWiersza>4</tns:NumerWiersza>
		<tns:DataOperacji>2022-02-11</tns:DataOperacji>
		<tns:NazwaPodmiotu>cccc</tns:NazwaPodmiotu>
		<tns:OpisOperacji>kaufland</tns:OpisOperacji>
		<tns:KwotaOperacji>-75.00</tns:KwotaOperacji>
		<tns:SaldoOperacji>165.00</tns:SaldoOperacji>
	</tns:WyciagWiersz>
	<tns:WyciagWiersz
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:NumerWiersza>5</tns:NumerWiersza>
		<tns:DataOperacji>2022-02-12</tns:DataOperacji>
		<tns:NazwaPodmiotu>dddd</tns:NazwaPodmiotu>
		<tns:OpisOperacji>fryzjer</tns:OpisOperacji>
		<tns:KwotaOperacji>-42.00</tns:KwotaOperacji>
		<tns:SaldoOperacji>123.00</tns:SaldoOperacji>
	</tns:WyciagWiersz>
	<tns:WyciagCtrl
		xmlns:etd="http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2018/08/24/eD/DefinicjeTypy/"
		xmlns:tns="http://jpk.mf.gov.pl/wzor/2019/09/27/09271/">
		<tns:LiczbaWierszy>5</tns:LiczbaWierszy>
		<tns:SumaObciazen>139.00</tns:SumaObciazen>
		<tns:SumaUznan>138.00</tns:SumaUznan>
	</tns:WyciagCtrl>
</tns:JPK>

*/
