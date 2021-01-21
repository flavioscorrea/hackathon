#INCLUDE "PROTHEUS.CH"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "RESTFUL.CH"
#INCLUDE "PONAPI01.CH"
#INCLUDE "TBICONN.CH"

Static __oSt01 := Nil//fBuscaNSR()
Static __oSt02 := Nil//fProxRegVal()
Static __oSt03 := Nil//fValidaNSR()

/*/{Protheus.doc} PONAPI01
//Realiza a busca pelas marcações da API Clock In da Carol e grava as informações na tabela de TSA do Protheus.
@author Wesley Alves Pereira
@since 13/09/2019
@version undefined
@return return, return_description
/*/
Function PONAPI01(xWork,dInicio,dFinal,cCoDisp,nCodNSR)
Local aDisps		:= {} //Array de dispositivos da Carol
Local aDados    	:= {} //Array de Marcações da Carol
Local cDtIni    	:= ''
Local cDtFin    	:= ''
Local nCoutDisp 	:= 0
Local nPosDados 	:= 3
Local cTempDisp 	:= ''
Local lWorkFlow 	:= .F.
Local cCodNSR   	:= ''
Local aTempss   	:= {}
Local lNSRInfor 	:= .F.
Local aTitle    	:= { OemToAnsi(STR0024) }//"Erro na integração com a API Clockin da Carol"

Local cLockName 	:= "PONAPI01"+DTOS(DATE())

Private aLog		:= { {} }
Private lApiToken	:= .F.
Private lGeraTokn	:= .F.
Private lTemRR1		:= .F.

DEFAULT xWork   	:= .F. //Rotina no Browser
DEFAULT dInicio		:= STOD('20000101')
DEFAULT dFinal		:= DATE()
DEFAULT cCoDisp 	:= ''
DEFAULT nCodNSR 	:= 0

If ValType(xWork) == "A" //Proveniente de Schedule
	If Len(xWork) >= 2 .AND. Len(xWork) <= 4 
		lWorkFlow := .T.
		If ( ValType( xWork[2] ) == "C" .AND. ValType( xWork[1] ) == "C" ) 
			RPCSetType(3)
			PREPARE ENVIRONMENT EMPRESA (xWork[1]) FILIAL (xWork[2]) MODULO "GPE"
			lTemRR1	:= AliasInDic("RR1")
		Else
			ConsoleJob(STR0021) //"Para utilização da rotina em Schedule, informe a Empresa e a Filial no cadastro do Schedule e não utilize parametros!"
			Return (.F.)
		EndIf
	Else
		ConsoleJob(STR0021) //"Para utilização da rotina em Schedule, informe a Empresa e a Filial no cadastro do Schedule e não utilize parametros!"
		Return (.F.)
	EndIf
Else
	lTemRR1	:= AliasInDic("RR1")
EndIf

If !LockByName(cLockName,.F.,.F.,.T.)
 		If ! lWorkFlow
 			Help( ,, 'HELP',, STR0020, 1, 0) //"Esta rotina já está sendo utilizada em outro processo!"
		Else
			ConsoleJob(STR0020) //"Esta rotina já está sendo utilizada em outro processo!"
		EndIf
		
		Return (.F.)
EndIf

If !lTemRR1 .And. !fTemTab()
 	If ! fCriaTab(lWorkFlow)
 		If ! lWorkFlow
 			Help( ,, 'HELP',, STR0018, 1, 0) //"Não foi possível criar a tabela do processo de integração! Verifique as permissões necessárias."
		Else
			ConsoleJob(STR0018) //"Não foi possível criar a tabela do processo de integração! Verifique as permissões necessárias."
		EndIf
		
		UnLockByName(cLockName,.F.,.F.,.T.)
		
		Return (.F.)
	
	EndIf
EndIf

If nCodNSR < 0
	If ! lWorkFlow
		Help( ,, 'HELP',, STR0015, 1, 0) //"Verifique o Código NSR Informado, pois o mesmo somente aceita números positivos!"
	Else
		ConsoleJob(STR0015) //"Verifique o Código NSR Informado, pois o mesmo somente aceita números positivos!"
	EndIf

	UnLockByName(cLockName,.F.,.F.,.T.)
	
	Return (.F.)

Else
	cCodNSR := cValToChar(nCodNSR)
Endif

If nCodNSR > 0
	lNSRInfor := .T.
EndIf

If ! fValData(dInicio,dFinal)
	If ! lWorkFlow
		Help( ,, 'HELP',, STR0012, 1, 0) //"Verifique as Datas informadas para acesso ao Clockin da Carol."
	Else
		ConsoleJob(STR0012) //"Verifique as Datas informadas para acesso ao Clockin da Carol."
	EndIf
	
	UnLockByName(cLockName,.F.,.F.,.T.)
		
	Return (.F.)

EndIf

cDtIni := fTraData(dInicio)
cDtFin := fTraData(dFinal)

If Empty(cCoDisp) 
	aDisps := fDispBusc()
Else
	aAdd(aTempss,cCoDisp)
	aDisps := {.T.,,aTempss}
EndIf

If aDisps[1] .and. Len(aDisps[nPosDados]) > 0

	If lTemRR1
		dbSelectArea("RR1")
		If !fMigrRR1()
			If !lWorkFlow
				MsgAlert(STR0045)//"Erro na migração dos registros da tabela MSA_CONTROL_MARCAC para a tabela RR1. Será necessário reinicializar a tabela RR1 e reiniciar o processo. A integração será abortada"
			Else
				ConsoleJob(STR0045)//"Erro na migração dos registros da tabela MSA_CONTROL_MARCAC para a tabela RR1. Será necessário reinicializar a tabela RR1 e reiniciar o processo. A integração será abortada"
			EndIf				
			Return .F.
		EndIf
	EndIf

	For nCoutDisp:= 1 To Len(aDisps[nPosDados])
	
		cTempDisp := aDisps[nPosDados][nCoutDisp]
		aDados := fMarcBusc(cTempDisp,cDtIni,cDtFin,lNSRInfor,cCodNSR)

		If aDados[1] .AND. Len (aDados[nPosDados]) > 0		
			fProcessa( cTempDisp, aDados[nPosDados],lWorkFlow, lNSRInfor )			
		Else		
			If aDados[2] <> Nil
				If ! aDados[1] .AND. AT("code",aDados[2]) > 0				
					If ! lWorkFlow
						fMakeLog( aLog, aTitle, Nil, Nil, , OemToAnsi(STR0025), "M", "L",, .F.) //"Log de Ocorrências"
					Else
						ConsoleJob(STR0007 + "  " + aDados[2]) //"Não foi possível acessar a API Clockin da Carol. "
					EndIf
					
					UnLockByName(cLockName,.F.,.F.,.T.)
					
					Return (.F.)
				
				EndIf
			Else
				If ! lWorkFlow
					Help( ,, 'HELP',, STR0007 + "  " + STR0011, 1, 0) //"Não foi possível acessar a API Clockin da Carol. " + "Verifique o parametro MV_APICLO8 pois ele é responsável pelo cadastro do path da api clockinrecordsList para a integração de Clockin da Carol."
				Else
					ConsoleJob(STR0007 + "  " + STR0011) //"Não foi possível acessar a API Clockin da Carol. " + "Verifique o parametro MV_APICLO8 pois ele é responsável pelo cadastro do path da api clockinrecordsList para a integração de Clockin da Carol." 
				EndIf
				
				UnLockByName(cLockName,.F.,.F.,.T.)
				
				Return (.F.)				
			
			EndIf
		EndIf
	
	Next nCoutDisp

Else
	If ! aDisps[1]
		If at("code",aDisps[2]) > 0		
			If ! lWorkFlow
				fMakeLog( aLog, aTitle, Nil, Nil, , OemToAnsi(STR0025), "M", "L",, .F.) //"Log de Ocorrências"
			Else
				ConsoleJob(STR0007 + "  " + aDisps[2]) //"Não foi possível acessar a API Clockin da Carol. "
			EndIf			
		Else
			If !Empty(aDisps[2])
				If ! lWorkFlow
					fMakeLog( aLog, aTitle, Nil, Nil, , OemToAnsi(STR0025), "M", "L",, .F.) //"Log de Ocorrências"
				Else
					ConsoleJob(aDisps[2]) //Mensagem de erro da API.
				EndIf
			EndIf
		EndIf
	EndIf
	
	UnLockByName(cLockName,.F.,.F.,.T.)
	
	Return (.F.)
	
EndIf

If ! lWorkFlow
	ApMsgInfo(STR0016+' '+STR0017) //" Processo Finalizado." + "Verifique as informações gravadas na tabela de marcações!"
Else
	ConsoleJob(STR0016+' '+STR0017) //" Processo Finalizado." + "Verifique as informações gravadas na tabela de marcações!"
EndIf 

UnLockByName(cLockName,.F.,.F.,.T.)

Return (.T.) 

/*/{Protheus.doc} fProcessa
Processa os dados recebidos gravando na tabela de referencia.
@author Wesley Alves Pereira
@since 17/09/2019
/*/
Function fProcessa(cDispo,aInfor,lWorkFlow,lNSRInfor)
Local nRegCount := 0
Local cQuery := ''
Local nHoraMarc := 0
Local cDataMarc := ''
Local nProxireg := 0
Local nNumDirec := 3
Local nNumFeder := 2
Local cNumdoPis := ''
Local cNumdoNSR := ''
Local cTempHora := ''
Local cCodclien := ''
Local cNomeSGDB := Upper(TCGetDB())
Local aParams	:= fBuscaParam()
Local lProcIni	:= .F.

cCodclien := aParams[4]
lProcIni  := aParams[14]

For nRegCount := 1 To Len(aInfor)

	nProxireg := 0
	cTempHora := ''
	nHoraMarc := 0
	cNumdoPis := ''
	cNumdoNSR := ''
	cDataMarc := ''	
	nNumDirec := 0
	nNumFeder := 0
	
	If lNSRInfor .Or. lProcIni
		If !fValidaNSR(cDispo,aInfor[nRegCount][2]) 
			loop
		EndIf
	EndIf
		
	If aInfor[nRegCount][8] <> Nil
		cTempHora := SubStr(aInfor[nRegCount][8],At("T",aInfor[nRegCount][8])+1,5)
		nHoraMarc := (( Val(SubStr(cTempHora,4,2))/60) + (Val(SubStr(cTempHora,1,2)))) * 3600		
	    cDataMarc := SubStr(aInfor[nRegCount][8],1,At('.',aInfor[nRegCount][8])-1)
	    If Alltrim(cNomeSGDB) == "ORACLE" 
	    	cDataMarc :=  StrTran(StrTran(cDataMarc,'T',''),'Z','')
	    EndIf 
	EndIf		
	 
	If aInfor[nRegCount][1] <> Nil
		cNumdoPis := aInfor[nRegCount][1] 
	EndIf
	 
	If aInfor[nRegCount][1] <> Nil
	 	cNumdoNSR := cValToChar(aInfor[nRegCount][2]) 
	EndIf
	 
	nProxireg := fProxRegVal()
	
	If !lTemRR1
		cQuery := " INSERT INTO MSA_CONTROL_MARCAC "
		cQuery += " (VAL_CONTROL_MARCAC, COD_REP, COD_PIS_MSA, COD_NSR, LOG_IMPORT_PRODUT, DAT_MARCAC_ACES,NUM_HORAR_MARCAC_ACES, NUM_DIRECAO_ACES, COD_ID_FEDER, COD_RELOGIO_EXT_CHAVE, COD_UNID_EXT_CHAVE ) "
		cQuery += " VALUES("+"'"+cValToChar(nProxireg)+"' ,"
		cQuery += " '"+'00001'+"' ," 
		cQuery += " '"+cNumdoPis +"' ,"
		cQuery += " '"+cNumdoNSR +"' ,"
		cQuery += " '"+'0' +"' ,"
		If Alltrim(cNomeSGDB) == "ORACLE"  
			cQuery += " to_date('"+cDataMarc+"' ,'YYYY-MM-DDHH24:MI:SS'),"
		Else
			cQuery += " '"+cDataMarc +"' ,"
		EndIf
		cQuery += " '"+cValToChar(nHoraMarc) +"' ,"
		cQuery += " '"+cValToChar(nNumDirec) +"' ,"	
		cQuery += " '"+cValToChar(nNumFeder) +"' ,"
		cQuery += " '"+cDispo+"' ,"
		cQuery += " '"+cCodclien+"' )"

		If TCSQLExec( cQuery ) < 0

			If ! lWorkFlow
				MsgStop("STR0014" + " - " +  TcSqlError() ) //"Ocorreu erro ao tentar atualizar a tabela 'MSA_CONTROL_MARCAC'"
			Else
				ConsoleJob("STR0014" + " - " +  TcSqlError()) //"Ocorreu erro ao tentar atualizar a tabela 'MSA_CONTROL_MARCAC'"
			EndIf
		
		Else
			TcSqlExec("COMMIT") 
		EndIf
	Else
		If RR1->( Reclock("RR1", .T.) )
			RR1->RR1_VALCON		:= nProxireg
			RR1->RR1_CODREL		:= cDispo
			RR1->RR1_NUMDA		:= nNumDirec
			RR1->RR1_CODFED		:= cValToChar(nNumFeder)
			RR1->RR1_LOGIP		:= "0"
			RR1->RR1_CODNSR		:= Val(cNumdoNSR)
			RR1->RR1_CODPIS		:= cNumdoPis
			RR1->RR1_DATMAR		:= sToD( StrTran( SubStr(cDataMarc, 1, 10), "-" ) )
			RR1->RR1_NUMMAR		:= nHoraMarc
			RR1->RR1_CODREP		:= "00001"
			RR1->RR1_CODUNI		:= cCodclien
			RR1->( MsUnlock() )
		Else
			If !lWorkFlow
				MsgStop(STR0046) //"Ocorreu erro ao tentar atualizar a tabela RR1"
			Else
				ConsoleJob(STR0046) //"Ocorreu erro ao tentar atualizar a tabela RR1"
			EndIf		
		EndIf
	EndIf
	
Next nRegCount
	
Return (.T.)

/*/{Protheus.doc} fMarcBusc
Busca a listagem de marcações de um determinado dispositivo.
@author Wesley Alves Pereira
@since 13/09/2019
/*/
Function fMarcBusc(cAccesCod,cDtIni,cDtFin,lNSRInfor,cCodNSR,lRetMarcs)
Local cSiteW    := '' 
Local aAccess	:= {} //AUTENTICAÇÃO DE USUÁRIO
Local aHeader	:= {} //ARRAY CONTENDO O AUTHORIZATION
Local oClient 	
Local cPageSize	:= "&pageSize=1000"
Local cURL		:= '' 
Local cAsort	:= "?indexType=MASTER&sortBy=mdmGoldenFieldAndValues.nsrcode&sortOrder=ASC&scrollable=false" 
Local cBody		:= ''
Local cFields	:= '&fields=mdmGoldenFieldAndValues.piscode,mdmGoldenFieldAndValues.nsrcode,mdmGoldenFieldAndValues.mdmeventdate,mdmGoldenFieldAndValues.eventdatestr,mdmGoldenFieldAndValues.mdmpersonid,mdmGoldenFieldAndValues.mdmname,mdmGoldenFieldAndValues.devicedescription'
Local cRet		:= ''
Local cRetCarol	:= ''
Local aMarcac	:= {} //ARRAY CONTENDO TODAS AS MARCAÇÕES DE UM DISPOSITIVO
Local cAuthlg	:= '' //CHECAGEM DE SUCESSÃO NA CONEXÃO 
Local oErro     := JsonObject():New()
Local oJson     := JsonObject():New()
Local lProcIni	:= .F.
Local lRet 		:= .F.
Local aParams	:= fBuscaParam()
Local lRepost	:= 0
Local nUltNSR	:= 0
Local nTot		:= 0

Default lRetMarcs := .F.

If lRetMarcs
	cFields	:= '&fields=mdmGoldenFieldAndValues.nsrcode'
EndIf

cSiteW 		:= aParams[2]
cURL   		:= aParams[9] 
lProcIni	:= aParams[14]

oClient := FwRest():New(cSiteW)

AAdd( aHeader, "Accept: application/json" )
AAdd( aHeader, "content-type: application/json" ) 
AAdd( aHeader, "charset: UTF-8" )  

aAccess	:= fConnCarol()
	
cAuthlg	:= IIF(Len(aAccess) > 2 .And. aAccess[2] != NIL ,aAccess[2],"") 

If !Empty(cAuthlg) .Or. lApiToken
	If !lApiToken
		aHeader[1] := "Authorization:" +cAuthlg
	Else
		AAdd( aHeader, "X-Auth-Key: " + aParams[12] )
		AAdd( aHeader, "X-Auth-ConnectorId: " + aParams[4] )
	EndIf

	cBody   := ""		
	cBody += '{' 
	cBody +=	'"deviceCode": "'+cAccesCod+'",'
	If !lNSRInfor
		cBody +=	'"nsrCode": "'+fBuscaNSR(cAccesCod, lProcIni)+'",'
	Else
		cBody +=	'"nsrCode": "'+cCodNSR+'"'
	EndIf
	cBody += '}'
		
	oClient:SetPostParams(cBody)
		
	cPageSize	:= "&pageSize=1000"
		
	oClient:SetPath(cURL + cAsort + cPageSize + cFields)
	
	If oClient:Post(aHeader) .And. at("totalHits",oClient:GetResult()) > 0
		Begin Sequence
			lRet := .T.
			cRet := oClient:GetResult()
			oJson:fromJson(cRet)
			If lRetMarcs
				nTot := oJson["totalHits"]
				Break
			EndIf
			If Len(oJson["hits"]) > 0
				fAddMarc( oJson, @aMarcac, @nUltNSR )
			EndIf
			If oJson["count"] < oJson["totalHits"] 
				lRepost := .T.
				While lRepost
					cBody   := ""					
					cBody 	+= '{' 
					cBody 	+=	'"deviceCode": "'+cAccesCod+'",'
					cBody 	+=	'"nsrCode": "'+cValToChar(nUltNSR+1)+'"'
					cBody 	+= '}'
					cPageSize	:= "&pageSize="+cValToChar(oJson["totalHits"])
					oClient:SetPostParams(cBody)
					oClient:SetPath(cURL + cAsort + cPageSize + cFields)	
					If oClient:Post(aHeader) .And. at("totalHits",oClient:GetResult()) > 0
						cRet := oClient:GetResult()
						oJson:fromJson(cRet)
						If Len(oJson["hits"]) > 0
							fAddMarc( oJson, @aMarcac, @nUltNSR )
						EndIf
						If !(oJson["count"] < oJson["totalHits"])
							lRepost := .F.
						EndIf
					Else
						lRepost := .F.
						lRet 	:= .F.
					EndIf
				End
			EndIf
		End Sequence
	Else	
		lRet 		:= .F.
		cRetCarol	:= oClient:GetResult()
		cRet 		:= "code:" + cRetCarol
		aMarcac 	:= {}
		oErro:fromJSON( cRetCarol )
		oErro:toJSON( cRetCarol )

		aAdd( aLog[1], STR0032 )//"Verifique se o path da API clockinrecordsList está informado corretamente no parâmetro MV_APICL08."
		aAdd( aLog[1], "")
		If !Empty( oErro:getJSONText( "code" ) ) .And. oErro:getJSONText( "code" ) != "null"
			aAdd( aLog[1], STR0027 + oErro:getJSONText( "code" ) )//"Código do erro retornado pela API: "
		EndIf
		If !Empty( oErro:getJSONText( "message" ) ) .And. oErro:getJSONText( "message" ) != "null"
			aAdd( aLog[1], STR0028 + oErro:getJSONText( "message" ) )//"Mensagem de erro retornado pela API: "
		EndIf
		aAdd( aLog[1], "")
		aAdd( aLog[1], STR0031 )//"Configuração dos parâmetros: "
		aAdd( aLog[1], "  MV_APICL01: " + aParams[2] )
		aAdd( aLog[1], "  MV_APICL02: " + aParams[3] )
		aAdd( aLog[1], "  MV_APICL03: " + aParams[4] )
		aAdd( aLog[1], "  MV_APICL04: " + aParams[5] )
		aAdd( aLog[1], "  MV_APICL05: " + aParams[6] )
		aAdd( aLog[1], "  MV_APICL06: " + aParams[7] )
		aAdd( aLog[1], "  MV_APICL07: " + aParams[8] )
		aAdd( aLog[1], "  MV_APICL08: " + aParams[9] )
		aAdd( aLog[1], "  MV_APICL09: " + aParams[10] )

		If aParams[13]
			aAdd( aLog[1], "  MV_APICL0A: " + aParams[12] )
		EndIf
		aAdd( aLog[1], "  MV_APICL0B: " + aParams[14] )

		aAdd( aLog[1], "")
		aAdd( aLog[1], STR0033)//"Erro completo retornado pela API da Carol: "
		FiltraLog( aLog[1], cRetCarol)
	EndIf
Else
	lRet := .F.
	If(Len(aAccess) > 3 .AND. aAccess[3] != NIL)
		cRet := "code:"+aAccess[3]
		aMarcac := {}
	Else
		If aAccess[5] <> Nil .AND. !Empty(aAccess[5])
			cRet := "code:"+aAccess[5]
			aMarcac := {}
		Endif		 
	EndIf
EndIf 

Return ( {lRet,cRet,aMarcac,nTot} )

/*/{Protheus.doc} fDispBusc
Função que retorna a lista de dispositivos.
@author edvf8
@since 12/09/2019
@version undefined
/*/
Function fDispBusc(deviceDescription)
Local cAuthlg	:= ""																//TOKEN DE ACESSO 
Local cPageSize	:= "&pageSize=" 													//PARAMETRIZAÇÃO PADRÃO DA API DEVICELIST(QUANTIDADE DE REGISTROS QUE DEVERÃO RETORNAR)
Local cAsort	:= "&sortOrder=ASC"  												//PARAMETRIZAÇÃO PADRÃO DA API DEVICELIST(ORDENAÇÃO DOS REGISTROS)
Local cIndexType:= "?indexType=MASTER" 												//PARAMETRIZAÇÃO PADRÃO DA API DEVICELIST(TIPO DE INDICE)
Local cFields	:= "&fields=mdmGoldenFieldAndValues.devicecode,mdmGoldenFieldAndValues.devicedescription"  					//PARAMETRIZAÇÃO PADRÃO DA API DEVICELIST(CAMPOS)
Local cURL		:= "" 																//URL DE ACESSO A CAROL
Local cBody		:= "" 																//CORPO DA REQUISIÇÃO CASO NECESSÁRIO, NESTA DEVICELIST NÃO POSSUI.
Local cRet		:= "" 																//ARMAZENA O RETORNO EM TEXTO DA API COM A LISTA DE DISPOSITIVOS
Local cRetCarol	:= "" 																//ARMAZENA O RETORNO EM TEXTO DA API COM A LISTA DE DISPOSITIVOS
Local lSucess	:= .T.
Local nContIds	:= "" 																//VARIAVEL DE CONTROLE PARA USO EM ESTRUTURA DE REPETIÇÃO

Local aAccess	:= fConnCarol()														//AUTENTICAÇÃO DE USUÁRIO
Local aParams	:= fBuscaParam() 													//BUSCA PARÂMETROS DE CONEXÃO COM A CAROL
Local aHeader	:= {} 																//ARRAY CONTENDO O AUTHORIZATION
Local aDisp		:= {} 																//ARRAY CONTENDO OS IDS DOS DISPOSITIVOS

Local oJson     := JsonObject():New()												//JSON QUE RECEBERÁ O RETORNO DA API
Local oErro     := JsonObject():New()												//JSON QUE RECEBERÁ O RETORNO DA API
Local oClient 	:= nil 																//OBJETO REST QUE SERÁ USADO NA REQUISIÇÃO
	
if !Empty(deviceDescription)
	cBody   := ""		
	cBody += '{' 
	cBody +=	'"deviceDescription": "'+deviceDescription+'"'
	cBody += '}'
EndIf
 	cAuthlg	:= IIF(Len(aAccess) > 2 .And. aAccess[2] != NIL ,aAccess[2],"") 		//CHECAGEM DE SUCESSO NA CONEXÃO E RETORNO DE TOKEN

	If !Empty(cAuthlg) .Or. lApiToken
		
		oClient 	:= FwRest():New(aParams[2])
		cURL		:= aParams[8] 
		
		oClient:SetPath(cURL + cIndexType + cAsort + cFields)
		
		If !lApiToken
			aHeader:= { "Authorization: Bearer " + cAuthlg,;
					"Content-Type: application/json; charset=UTF-8";
					}
		Else
			aHeader:= { "X-Auth-Key: " + aParams[12],;
					"X-Auth-ConnectorId: " + aParams[4],;
					"Content-Type: application/json; charset=UTF-8";
					}
		EndIf

		oClient:SetPostParams(cBody)

		If oClient:Post(aHeader) .And. at("hits",oClient:GetResult()) > 0
			cRet := oClient:GetResult()
			oJson:fromJson(cRet)
			If Len(oJson["hits"]) < oJson["totalHits"] 
				oClient:SetPath(cURL + cIndexType + cPageSize + cValToChar(oJson["totalHits"]) + cAsort + cFields)		
				oClient:Post(aHeader) 
				cRet := oClient:GetResult()
				oJson:fromJson(cRet)
			EndIf
			For nContIds:= 1 to Len(oJson["hits"])
				aAdd(aDisp,{oJson["hits"][nContIds]["mdmGoldenFieldAndValues"]["devicecode"],oJson["hits"][nContIds]["mdmGoldenFieldAndValues"]["devicedescription"],0})
			Next
			lSucess:= .T.
			
		Else
			cRet:= oClient:GetResult()
			lRet 		:= .F.
			cRetCarol	:= oClient:GetResult()
			cRet 		:= "code:" + cRetCarol
			oErro:fromJSON( cRetCarol )
			oErro:toJSON( cRetCarol )

			aAdd( aLog[1], STR0009 )//"Verifique o parametro MV_APICLO7 pois ele é responsável pelo cadastro do path da api DeviceList  para a integração de Clockin da Carol."
			aAdd( aLog[1], "")
			If !Empty( oErro:getJSONText( "code" ) ) .And. oErro:getJSONText( "code" ) != "null"
				aAdd( aLog[1], STR0027 + oErro:getJSONText( "code" ) )//"Código do erro retornado pela API: "
			EndIf
			If !Empty( oErro:getJSONText( "message" ) ) .And. oErro:getJSONText( "message" ) != "null"
				aAdd( aLog[1], STR0028 + oErro:getJSONText( "message" ) )//"Mensagem de erro retornado pela API: "
			EndIf
			aAdd( aLog[1], "")
			aAdd( aLog[1], STR0031 )//"Configuração dos parâmetros: "
			aAdd( aLog[1], "  MV_APICL01: " + aParams[2] )
			aAdd( aLog[1], "  MV_APICL02: " + aParams[3] )
			aAdd( aLog[1], "  MV_APICL03: " + aParams[4] )
			aAdd( aLog[1], "  MV_APICL04: " + aParams[5] )
			aAdd( aLog[1], "  MV_APICL05: " + aParams[6] )
			aAdd( aLog[1], "  MV_APICL06: " + aParams[7] )
			aAdd( aLog[1], "  MV_APICL07: " + aParams[8] )
			aAdd( aLog[1], "  MV_APICL08: " + aParams[9] )
			aAdd( aLog[1], "  MV_APICL09: " + aParams[10] )

			If aParams[13]
				aAdd( aLog[1], "  MV_APICL0A: " + aParams[12] )
			EndIf
			aAdd( aLog[1], "  MV_APICL0B: " + aParams[14] )

			aAdd( aLog[1], "")
			aAdd( aLog[1], STR0033)//"Erro completo retornado pela API da Carol: "
			FiltraLog( aLog[1], cRetCarol)
			lSucess:= .F.
		EndIf

	Else
		lSucess:= .F.
		cRet:= aAccess[5]
	EndIf 
	
Return {lSucess,cRet,aDisp}


/*/{Protheus.doc} fConnCarol
Programa de liberação de Token para acesso a API´s Clock In da Carol
@author Wesley Alves Pereira
@since 12/09/2019
@return return, return_description
/*/
Function fConnCarol()

Local aHeader   := {}
Local aRetorno  := {}
Local aParam    := {}
Local cParams   := ""
Local cRet      := ""
Local cRetCarol := ""
Local cPath     := ""
Local ccURL		:= ""
Local cErro     := ""
Local nCont		:= 0
Local oErro     := JsonObject():New()
Local oRet      := JsonObject():New()
Local lSucess   := .T.
Local lErro		:= .F.
Local lAtuaToken:= .F.
Local oObj		:= Nil
Local oClient   := Nil
 
aParam := fBuscaParam()

If Empty(aParam[2])
	aAdd( aLog[1], STR0001 ) //"Verifique o parametro MV_APICLO1 pois ele é responsável pelo cadastro da URL de EndPoint para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If Empty(aParam[3]) .OR. aParam[3] == "/" 
	aAdd( aLog[1], STR0002 ) //"Verifique o parametro MV_APICLO2 pois ele é responsável pelo cadastro do path da api Token para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If Empty(aParam[4])
	aAdd( aLog[1], STR0003 ) //"Verifique o parametro MV_APICLO3 pois ele é responsável pelo cadastro do Id Conector para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If Empty(aParam[7])
	aAdd( aLog[1], STR0006 ) //"Verifique o parametro MV_APICLO6 pois ele é responsável pelo cadastro do Domain Name para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If Empty(aParam[8]) .OR. aParam[8] == "/" 
	aAdd( aLog[1], STR0009 ) //"Verifique o parametro MV_APICLO7 pois ele é responsável pelo cadastro do path da api DeviceList  para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If Empty(aParam[9]) .OR. aParam[9] == "/" 
	aAdd( aLog[1], STR0011 ) //"Verifique o parametro MV_APICLO8 pois ele é responsável pelo cadastro do path da api clockinrecordsList para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If Empty(aParam[10]) 
	aAdd( aLog[1], STR0044 ) //"Verifique o parametro MV_APICLO9 pois ele é responsável pelo cadastro do Organization Name para a integração de Clockin da Carol."
	lErro := .T.
EndIf

If ( (Empty(aParam[5]) .Or. Empty(aParam[6]) ) .And. Empty(aParam[12]) )
	aAdd( aLog[1], STR0043 ) //"Para realizar a integração será necessário preencher os parâmetros MV_APICLO4 e MV_APICLO5 ou MV_APICLOA."
	lErro := .T.
EndIf

If lErro
	lSucess := .F.

	aAdd( aLog[1], "")
	aAdd( aLog[1], STR0031 )//"Configuração dos parâmetros: "
	aAdd( aLog[1], "  MV_APICL01: " + aParam[2] )
	aAdd( aLog[1], "  MV_APICL02: " + aParam[3] )
	aAdd( aLog[1], "  MV_APICL03: " + aParam[4] )
	aAdd( aLog[1], "  MV_APICL04: " + aParam[5] )
	aAdd( aLog[1], "  MV_APICL05: " + aParam[6] )
	aAdd( aLog[1], "  MV_APICL06: " + aParam[7] )
	aAdd( aLog[1], "  MV_APICL07: " + aParam[8] )
	aAdd( aLog[1], "  MV_APICL08: " + aParam[9] )
	aAdd( aLog[1], "  MV_APICL09: " + aParam[10] )

	If aParam[13]
		aAdd( aLog[1], "  MV_APICL0A: " + aParam[12] )	
	EndIf
	aAdd( aLog[1], "  MV_APICL0B: " + aParam[14] )	

	aAdd(aRetorno,lSucess)
	aAdd(aRetorno,Nil)
	aAdd(aRetorno,Nil)
	aAdd(aRetorno,"")
	aAdd(aRetorno,STR0042)

	Return (aRetorno)
EndIf

// Verifica se a autenticação deve ser realizada via API Token
If !Empty(aParam[12])
	// Faz um teste do Connector Token informado
	ccURL	:= aParam[2]
	cPath	:= "/api/v3/apiKey/details"
	cParams := "apiKey=" + aParam[12] +"&"
	cParams += "connectorId=" + aParam[4]

	AAdd( aHeader, "Accept: application/json" )
	AAdd( aHeader, "X-Auth-Key: " + aParam[12] )
	AAdd( aHeader, "X-Auth-ConnectorId: " + aParam[4] )

	oClient := FwRest():New(ccURL)
	oClient:SetPath(cPath)
	oClient:SetPostParams(cParams)
	oClient:Get(aHeader,cParams)

	If FWJsonDeserialize(oClient:GetResult(),@oObj)
		If oObj <> Nil
			cRet := oClient:GetResult()
			If oRet:fromJson(cRet) == Nil .And. oRet["errorCode"] == Nil
				lApiToken := .T.
				lSucess := .T.
				cErro := "ok"
			Else
				oErro:fromJSON( cRet )
				oErro:toJSON( cRet )
				If !Empty( oErro:getJSONText( "errorCode" ) ) .And. oErro:getJSONText( "errorCode" ) == "404" .And. oErro:getJSONText( "possibleResponsibleField" ) == "apiKey" 
					lAtuaToken := .T.
				ElseIf !Empty( oErro:getJSONText( "errorCode" ) ) .And. oErro:getJSONText( "errorCode" ) == "404" .And. oErro:getJSONText( "possibleResponsibleField" ) == "mdmName" 
					aAdd( aLog[1], STR0038 )//"O Connector Id preenchido no parâmetro MV_APICLO3 está incorreto."
					aAdd( aLog[1], STR0040 )//"Foi realizado uma tentativa de autenticação por usuário e senha."
					aAdd( aLog[1], "")
				EndIf
			EndIf
		EndIf
	EndIf
Else
	If Len(aLog) > 0
		If Len(aLog[1]) > 0
			If !aScan(aLog, {|x| x[1] == "Falha na autenticação por API Key (Opcional)."}) > 0
				aAdd( aLog[1], STR0039 )//"Falha na autenticação por API Key (Opcional)."
				aAdd( aLog[1], STR0041 )//"Para utilizar a autenticação por API Key crie o parâmetro MV_APICLOA e preencha com o token gerado pela Carol."
				aAdd( aLog[1], STR0040 )//"Foi realizado uma tentativa de autenticação por usuário e senha."
				aAdd( aLog[1], "" )
			EndIf
		Else
			aAdd( aLog[1], STR0039 )//"Falha na autenticação por API Key (Opcional)."
			aAdd( aLog[1], STR0041 )//"Para utilizar a autenticação por API Key crie o parâmetro MV_APICLOA e preencha com o token gerado pela Carol."
			aAdd( aLog[1], STR0040 )//"Foi realizado uma tentativa de autenticação por usuário e senha."
			aAdd( aLog[1], "" )
		EndIf
	EndIf
EndIf

If !lApiToken
	// Autenticação utilizando usuário e senha para gerar o Access Token
	aHeader := {}
	AAdd( aHeader, "Accept: application/json" )
	AAdd( aHeader, "Content-Type: application/x-www-form-urlencoded" )
	ccURL := aParam[2]
	cPath := aParam[3]
	cParams := "grant_type=password&"
	cParams += "connectorId=" + aParam[4] + "&"
	cParams += "username=" + aParam[5] + "&"
	cParams += "password=" + aParam[6] + "&"
	cParams += "subdomain=" + AllTrim(aParam[10]) + "&"
	cParams += "orgSubdomain=" + aParam[7]
	
	oClient := FwRest():New(ccURL)
	oClient:SetPath(cPath)
	oClient:SetPostParams(cParams)
	If lSucess .And. oClient:Post(aHeader)
		If FWJsonDeserialize(oClient:GetResult(),@oObj)
			If oObj <> Nil			
				cRet := oClient:GetResult()
				If oRet:fromJson(cRet) == Nil .And. oRet["access_token"] <> Nil
					lSucess := .T.
					cErro := "ok"
					// Tenta gerar o API Token se não existir, para ser utilizado
					// em integrações futuras
					If ( !lGeraTokn .And. aParam[13] .And. Empty( aParam[12] ) ) .Or. lAtuaToken
						fGeraApiTk( aParam[2], oRet:GetJsonText( "access_token" ), aParam[4], aParam[10] )
					EndIf
				EndIf
			EndIf
		EndIf	
	Else	
		lSucess := .F.
		cRet := oClient:GetResult()

		If lAtuaToken
			aAdd( aLog[1], STR0037 )//"API Key (Connector Token) inválida, verifique se a API Key está correta ou revogue, gere uma nova API Key e preencha no parâmetro MV_APICLOA."
			aAdd( aLog[1], STR0040 )//"Foi realizado uma tentativa de autenticação por usuário e senha."
			aAdd( aLog[1], "")
		EndIf
		If Empty(cRet)
			aAdd( aLog[1], STR0007)//"Não foi possível acessar a API Clockin da Carol. "
			aAdd( aLog[1], STR0026 )//"Verifique se a URL de Endpoint da Carol está informada corretamente no parâmetro MV_APICL01."
		Else
			cRetCarol := cRet
			oErro:fromJSON( cRet )
			oErro:toJSON( cRet )		
			If !Empty( oErro:getJSONText( "code" ) ) .And. oErro:getJSONText( "code" ) != "null" .And. ( Empty( oErro:getJSONText( "errorCode" ) ) .Or. oErro:getJSONText( "errorCode" ) == "null")
				aAdd( aLog[1], STR0034 )//"Verifique se o path de acesso da API da Carol está informada corretamente no parâmetro MV_APICL02."
				aAdd( aLog[1], "")
			EndIf
			If !Empty( oErro:getJSONText( "errorCode" ) ) .And. oErro:getJSONText( "errorCode" ) != "null" .And. ( Empty( oErro:getJSONText( "code" ) ) .Or. oErro:getJSONText( "code" ) == "null")
				If oErro:getJSONText( "errorCode" ) == "400" .Or. oErro:getJSONText( "errorCode" ) == "401"
					aAdd( aLog[1], STR0035 )//"Verifique se o usuário e a senha estão informados corretamente nos parâmetros MV_APICLO4 e MV_APICLO5."
				ElseIf !Empty( oErro:getJSONText( "errorCode" ) ) .And. oErro:getJSONText( "errorCode" ) == "404" .And. oErro:getJSONText( "possibleResponsibleField" ) == "mdmSubdomain" 
					aAdd( aLog[1], STR0036 )//"Verifique se o subdomínio e a organização estão informados corretamente nos parâmetros MV_APICLO6 e MV_APICLO9."
				ElseIf !Empty( oErro:getJSONText( "errorCode" ) ) .And. oErro:getJSONText( "errorCode" ) == "404" .And. oErro:getJSONText( "possibleResponsibleField" ) == "mdmName" 
					aAdd( aLog[1], "Verifique se o Connector Id preenchido no parâmetro MV_APICLO3 está correto." )//"Verifique se o Connector Id preenchido no parâmetro MV_APICLO3 está correto."
				EndIf
				aAdd( aLog[1], "")
			EndIf
			If !Empty( oErro:getJSONText( "errorCode" ) ) .And. oErro:getJSONText( "errorCode" ) != "null"
				aAdd( aLog[1], STR0027 + oErro:getJSONText( "errorCode" ) )//"Código do erro retornado pela API: "
			EndIf
			If !Empty( oErro:getJSONText( "code" ) ) .And. oErro:getJSONText( "code" ) != "null"
				aAdd( aLog[1], STR0027 + oErro:getJSONText( "code" ) )//"Código do erro retornado pela API: "
			EndIf
			If !Empty( oErro:getJSONText( "errorMessage" ) ) .And. oErro:getJSONText( "errorMessage" ) != "null"
				aAdd( aLog[1], STR0028 + oErro:getJSONText( "errorMessage" ) )//"Mensagem de erro retornado pela API: "
			EndIf
			If !Empty( oErro:getJSONText( "message" ) ) .And. oErro:getJSONText( "message" ) != "null"
				aAdd( aLog[1], STR0028 + oErro:getJSONText( "message" ) )//"Mensagem de erro retornado pela API: "
			EndIf
			If !Empty( oErro:getJSONText( "possibleResponsibleField" ) ) .And. oErro:getJSONText( "possibleResponsibleField" ) != "null"
				aAdd( aLog[1], STR0029 + oErro:getJSONText( "possibleResponsibleField" ) )//"Possível campo responsável pelo erro retornado pela API: "
			EndIf
			If !Empty( oErro:getJSONText( "applicationErrorCode" ) ) .And. oErro:getJSONText( "applicationErrorCode" ) != "null"
				aAdd( aLog[1], STR0030 + oErro:getJSONText( "applicationErrorCode" ) )//"Código do erro retornado pela aplicação: "
			EndIf
		EndIf
		aAdd( aLog[1], "")
		aAdd( aLog[1], STR0031 )//"Configuração dos parâmetros: "
		aAdd( aLog[1], "  MV_APICL01: " + aParam[2] )
		aAdd( aLog[1], "  MV_APICL02: " + aParam[3] )
		aAdd( aLog[1], "  MV_APICL03: " + aParam[4] )
		aAdd( aLog[1], "  MV_APICL04: " + aParam[5] )
		aAdd( aLog[1], "  MV_APICL05: " + aParam[6] )
		aAdd( aLog[1], "  MV_APICL06: " + aParam[7] )
		aAdd( aLog[1], "  MV_APICL07: " + aParam[8] )
		aAdd( aLog[1], "  MV_APICL08: " + aParam[9] )
		aAdd( aLog[1], "  MV_APICL09: " + aParam[10] )

		If aParam[13]
			aAdd( aLog[1], "  MV_APICL0A: " + aParam[12] )
		EndIf
		aAdd( aLog[1], "  MV_APICL0B: " + aParam[14] )

		If !Empty(cRetCarol)
			aAdd( aLog[1], "")
			aAdd( aLog[1], STR0033)//"Erro completo retornado pela API da Carol: "
			FiltraLog( aLog[1], cRetCarol)
		EndIf
	EndIf
EndIf    

If cRet == Nil
	cRet := ""
EndIf

aAdd(aRetorno,lSucess)

If lSucess
	If !lApiToken
		aAdd(aRetorno,oRet:GetJsonText("access_token"))
		aAdd(aRetorno,oRet)
	EndIf
Else
	aAdd(aRetorno,Nil)
	aAdd(aRetorno,Nil)

	For nCont := 1 To Len( aLog[1] )
		cErro += aLog[1, nCont] + CRLF
	Next nCont
EndIf


If !lApiToken
	aAdd(aRetorno,cRet)
	aAdd(aRetorno,cErro)
EndIf

Return (aRetorno)

/*/{Protheus.doc} fBuscaParam
Carregando os parâmetros
@author Wesley Alves Pereira
@since 12/09/2019
/*/
Static Function fBuscaParam()
Local aParam 	:= {}
Local lTipoI 	:= SUPERGETMV('MV_APICLO0', .F., .F.)
Local cSiteW 	:= Alltrim(SUPERGETMV('MV_APICLO1', .F., ''))
Local cPathW 	:= Alltrim(SUPERGETMV('MV_APICLO2', .F., ''))
Local cConec 	:= Alltrim(SUPERGETMV('MV_APICLO3', .F., ''))
Local cUsern 	:= Alltrim(SUPERGETMV('MV_APICLO4', .F., ''))
Local cPassw 	:= Alltrim(SUPERGETMV('MV_APICLO5', .F., ''))
Local cDomin 	:= Alltrim(SUPERGETMV('MV_APICLO6', .F., ''))
Local cPathD 	:= Alltrim(SUPERGETMV('MV_APICLO7', .F., ''))
Local cPathM 	:= Alltrim(SUPERGETMV('MV_APICLO8', .F., ''))
Local lOrgExist	:= SUPERGETMV('MV_APICLO9',.F.,.F.)
Local cOrg	 	:= Alltrim(SUPERGETMV('MV_APICLO9', .F., ''))
Local lApiExist	:= SUPERGETMV('MV_APICLOA',.F.,.F.)
Local cApiToken	:= Alltrim(SUPERGETMV('MV_APICLOA', .F., ''))
Local lProcIni	:= SUPERGETMV('MV_APICLOB',.F.,.F.)

lOrgExist := ValType(lOrgExist) == "C"
lApiExist := ValType(lApiExist) == "C"

aAdd(aParam,lTipoI)
aAdd(aParam,cSiteW)
aAdd(aParam,Iif(Substr(cPathW,1,1) <> '/', '/'+cPathW, cPathW ))
aAdd(aParam,cConec)
aAdd(aParam,cUsern)
aAdd(aParam,cPassw)
aAdd(aParam,cDomin)
aAdd(aParam,Iif(Substr(cPathD,1,1) <> '/', '/'+cPathD, cPathD ))
aAdd(aParam,Iif(Substr(cPathM,1,1) <> '/', '/'+cPathM, cPathM ))
aAdd(aParam,cOrg)
aAdd(aParam,lOrgExist)
aAdd(aParam,cApiToken)
aAdd(aParam,lApiExist)
aAdd(aParam,lProcIni)

Return (aParam)

/*/{Protheus.doc} fBuscaNSR
Busca o código NSR do último dispositivo lido.
@author Wesley Alves Pereira
@since 12/09/2019
/*/
Static Function fBuscaNSR(cAccesCod, lProcIni)

Local nContador := 0
Local cAliasTMP := GetNextAlias()
Local cSelect	:= ""
Local cTabInteg := ""
Local cWhere 	:= ""
Local cQuery 	:= ""

If !lTemRR1
	If !lProcIni
		cSelect 	:= "MAX(COD_NSR) AS MAXIMO"
	Else
		cSelect 	:= "MIN(COD_NSR) AS MAXIMO"
	EndIf
	cTabInteg 		:= "MSA_CONTROL_MARCAC"
	If !lProcIni
		cWhere 		:= "COD_RELOGIO_EXT_CHAVE = ?"
	Else
		cWhere 		:= "COD_RELOGIO_EXT_CHAVE = ? AND COD_NSR+1 NOT IN (SELECT COD_NSR FROM MSA_CONTROL_MARCAC WHERE COD_RELOGIO_EXT_CHAVE = ?)"
	EndIf
Else
	If !lProcIni
		cSelect 	:= "MAX(RR1_CODNSR) AS MAXIMO"
	Else
		cSelect 	:= "MIN(RR1_CODNSR) AS MAXIMO%"
	EndIf
	cTabInteg 		:= RetSqlName('RR1')
	If !lProcIni
		cWhere 		:= "RR1_CODREL = ?"
	Else
		cWhere 		:= "RR1_CODREL = ? AND RR1_CODNSR+1 NOT IN (SELECT RR1_CODNSR FROM "+RetSqlName('RR1')+" WHERE COD_RELOGIO_EXT_CHAVE = ?)"
	EndIf
EndIf

If __oSt01 == Nil
	__oSt01 := FWPreparedStatement():New()

	cQuery := "SELECT " + cSelect
	cQuery += " FROM " + cTabInteg
	cQuery += " WHERE " + cWhere
	cQuery := ChangeQuery(cQuery)
		
	__oSt01:SetQuery(cQuery)
EndIf

__oSt01:SetString(1, cAccesCod)
If lProcIni
	__oSt01:SetString(2, cAccesCod)
EndIf

cQuery := __oSt01:getFixQuery()

dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasTMP, .T., .T.)

nContador := (cAliasTMP)->(MAXIMO)
nContador++

( cAliasTMP )->(dbCloseArea())

Return (cValToChar(nContador))

/*/{Protheus.doc} fValData
Valida as informações de data passadas por parametro
@author Wesley Alves Pereira
@since 12/09/2019
/*/
Static Function fValData(di,df)
Local lReto := .F.

If !Empty(di) .AND. !Empty(df) 
	lReto := .T.
EndIf

Return (lReto)

/*/{Protheus.doc} fTraData
Transforma uma data no padrão da API
@author Wesley Alves Pereira
@since 12/09/2019
/*/
Static Function fTraData(dData)
Local cData := ''
Local cTemp := DTOS(dData)
cData := Substr(cTemp,1,4) + '-' + Substr(cTemp,5,2) + '-' + Substr(cTemp,7,2) + 'T00:00:00'

Return (cData)

/*/{Protheus.doc} fProxRegVal
Busca o proximo registro sequencial da tabela.
@author Wesley Alves Pereira
@since 17/09/2019
/*/
Static Function fProxRegVal()

Local nContador := 0
Local cAliasTMP := GetNextAlias()
Local cSelect	:= ""
Local cTabInteg := ""
Local cQuery 	:= ""

If !lTemRR1
	cSelect 	:= "MAX(VAL_CONTROL_MARCAC) AS MAXIMO"
	cTabInteg 	:= "MSA_CONTROL_MARCAC"
Else
	cSelect 	:= "MAX(RR1_VALCON) AS MAXIMO"
	cTabInteg 	:= RetSqlName('RR1')
EndIf

If __oSt02 == Nil
	__oSt02 := FWPreparedStatement():New()

	cQuery := "SELECT " + cSelect
	cQuery += " FROM " + cTabInteg
	cQuery := ChangeQuery(cQuery)
		
	__oSt02:SetQuery(cQuery)
EndIf

cQuery := __oSt02:getFixQuery()

dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasTMP, .T., .T.)

nContador := (cAliasTMP)->(MAXIMO)

( cAliasTMP )->(dbCloseArea())

nContador += 1

Return (nContador)

/*/{Protheus.doc} fValidaNSR
Valida se o NSR Informado já existe na tabela.
@author Wesley Alves Pereira
@since 19/09/2019
/*/
Static Function fValidaNSR(cDispo,cCodNSR) 

Local nContador := 0
Local cAliasTMP := GetNextAlias()
Local cSelect	:= ""
Local cTabInteg := ""
Local cWhere 	:= ""
Local lRetorno 	:= .T.
Local cQuery 	:= ""

If !lTemRR1
	cSelect 	:= "VAL_CONTROL_MARCAC"
	cTabInteg 	:= "MSA_CONTROL_MARCAC
	cWhere 		:= "COD_RELOGIO_EXT_CHAVE = ? AND COD_NSR = ?"
Else
	cSelect 	:= "RR1_VALCON AS VAL_CONTROL_MARCAC"
	cTabInteg 	:= RetSqlName('RR1')
	cWhere 		:= "RR1_CODREL = ? AND RR1_CODNSR = ?"
EndIf

If __oSt03 == Nil
	__oSt03 := FWPreparedStatement():New()

	cQuery := "SELECT " + cSelect
	cQuery += " FROM " + cTabInteg
	cQuery += " WHERE " + cWhere
	cQuery := ChangeQuery(cQuery)
		
	__oSt03:SetQuery(cQuery)
EndIf

__oSt03:SetString(1, cDispo)
__oSt03:SetString(2, cValToChar(cCodNSR))

cQuery := __oSt03:getFixQuery()

dbUseArea(.T., "TOPCONN", TcGenQry(,, cQuery), cAliasTMP, .T., .T.)

nContador := (cAliasTMP)->(VAL_CONTROL_MARCAC)

( cAliasTMP )->(dbCloseArea())

If nContador > 0
	lRetorno := .F.
EndIf

Return (lRetorno)

/*/{Protheus.doc} ConsoleJob
Exibe uma mensagem no console quando a rotina for via Schedule.
@author Wesley Alves Pereira
@since 18/09/2019
/*/
Static Function ConsoleJob(cMensagem)

Conout(Replicate("-",30))
Conout(FwNoAccent(OemToAnsi(STR0013))) //"Execução da Rotina PONAPI01 - Via Schedule"
Conout(FwNoAccent(OemToAnsi(cMensagem)))
Conout(Replicate("-",30))

Return (.T.)

/*/{Protheus.doc} fTemTab
Verifica a existencia da tabela de integração.
@author Wesley Alves Pereira
@since 21/10/2019
/*/
Static Function fTemTab()
Local lReto := .T.

If ! TcCanOpen('MSA_CONTROL_MARCAC')
	lReto := .F.
EndIf

Return (lReto) 	

/*/{Protheus.doc} fCriaTab
Realiza a criação da tabela de integração.
@author Wesley Alves Pereira
@since 21/10/2019
/*/
Static Function fCriaTab(lWorkFlow)
Local lReto := .T.
Local cNomeSGDB := Upper(TCGetDB())

Local cTcQry := ""
Local cReto := ""
Local lTrata := .F.

If Alltrim(cNomeSGDB) == "MSSQL"

	lTrata := .T.
	
	cTcQry := "	CREATE TABLE [dbo].[MSA_CONTROL_MARCAC]( "
	cTcQry += "		[VAL_CONTROL_MARCAC] [bigint] PRIMARY KEY NOT NULL, "
	cTcQry += "		[COD_ID_PREVID_SOCIAL] [varchar](20), "
	cTcQry += "		[COD_RELOGIO_EXT_CHAVE] [varchar](100), "
	cTcQry += "		[NUM_DIRECAO_ACES] [int] NOT NULL, "
	cTcQry += "		[COD_FUNC_MSA] [varchar](100), "
	cTcQry += "		[COD_ID_FEDER] [varchar](50) NOT NULL, "
	cTcQry += "		[COD_HASH] [varchar] (255), "
	cTcQry += "		[LOG_IMPORT_PRODUT] [tinyint], "
	cTcQry += "		[COD_LOTE] [varchar] (100), "
	cTcQry += "		[COD_NSR] [int] NOT NULL, "
	cTcQry += "		[COD_PIS_MSA] [varchar] (12) NOT NULL, "
	cTcQry += "		[VAL_PERF_ACES] [int], "
	cTcQry += "		[DAT_MARCAC_ACES] [datetime] NOT NULL, "
	cTcQry += "		[NUM_HORAR_MARCAC_ACES] [int] NOT NULL, "
	cTcQry += "		[COD_REP] [varchar] (17) NOT NULL, "
	cTcQry += "		[COD_UNID_EXT_CHAVE] [varchar] (100), "
	cTcQry += "		[COD_USUAR_EXT_CHAVE] [varchar] (100)	
	cTcQry += ")  "
	
ElseIf Alltrim(cNomeSGDB) == "ORACLE"

	lTrata := .T.
	
	cTcQry := "	CREATE TABLE MSA_CONTROL_MARCAC ( "
	cTcQry += "		VAL_CONTROL_MARCAC NUMBER(19) PRIMARY KEY NOT NULL, "
	cTcQry += "		COD_ID_PREVID_SOCIAL varchar2 (20), "
	cTcQry += "		COD_RELOGIO_EXT_CHAVE varchar2 (100), "
	cTcQry += "		NUM_DIRECAO_ACES NUMBER(10) NOT NULL, "
	cTcQry += "		COD_FUNC_MSA varchar2 (100), "
	cTcQry += "		COD_ID_FEDER varchar2 (50) NOT NULL, "
	cTcQry += "		COD_HASH varchar2 (255), "
	cTcQry += "		LOG_IMPORT_PRODUT NUMBER(3), "
	cTcQry += "		COD_LOTE varchar2 (100), "
	cTcQry += "		COD_NSR NUMBER(10) NOT NULL, "
	cTcQry += "		COD_PIS_MSA varchar2 (12) NOT NULL, "
	cTcQry += "		VAL_PERF_ACES NUMBER(10), "
	cTcQry += "		DAT_MARCAC_ACES DATE NOT NULL, "
	cTcQry += "		NUM_HORAR_MARCAC_ACES NUMBER(10) NOT NULL, "
	cTcQry += "		COD_REP varchar2 (17) NOT NULL, "
	cTcQry += "		COD_UNID_EXT_CHAVE varchar2 (100), "
	cTcQry += "		COD_USUAR_EXT_CHAVE varchar2 (100)	
	cTcQry += ")  "

ElseIf Alltrim(cNomeSGDB) == "POSTGRES"

	lTrata := .T.
	
	cTcQry := "	CREATE TABLE MSA_CONTROL_MARCAC ( "
	cTcQry += "		VAL_CONTROL_MARCAC bigint PRIMARY KEY NOT NULL, "
	cTcQry += "		COD_ID_PREVID_SOCIAL varchar(20), "
	cTcQry += "		COD_RELOGIO_EXT_CHAVE varchar(100), "
	cTcQry += "		NUM_DIRECAO_ACES int NOT NULL, "
	cTcQry += "		COD_FUNC_MSA varchar(100), "
	cTcQry += "		COD_ID_FEDER varchar(50) NOT NULL, "
	cTcQry += "		COD_HASH varchar(255), "
	cTcQry += "		LOG_IMPORT_PRODUT smallint, "
	cTcQry += "		COD_LOTE varchar (100), "
	cTcQry += "		COD_NSR int NOT NULL, "
	cTcQry += "		COD_PIS_MSA varchar (12) NOT NULL, "
	cTcQry += "		VAL_PERF_ACES int, "
	cTcQry += "		DAT_MARCAC_ACES Date NOT NULL, "
	cTcQry += "		NUM_HORAR_MARCAC_ACES int NOT NULL, "
	cTcQry += "		COD_REP varchar (17) NOT NULL, "
	cTcQry += "		COD_UNID_EXT_CHAVE varchar (100), "
	cTcQry += "		COD_USUAR_EXT_CHAVE varchar (100)	
	cTcQry += ")  "
	
EndIf

If lTrata
	//Executa a query	
	If TcSqlExec(cTcQry) < 0
		cReto := TcSqlError()
		lReto := .F.
		If !lWorkFlow
			Help( ,, 'HELP',, cReto, 1, 0) //Mensagem de erro na Criação da tabela de integração
		Else
			ConsoleJob(cReto) //Mensagem de erro na Criação da tabela de integração
		EndIf
	EndIf
Else
	lReto := .F.
EndIf

Return (lReto)

/*/{Protheus.doc} FiltraLog
//Função que quebra o texto para gravação no log
@author paulo.inzonha
@since 25/07/2019
@version 1.0
@return NIL
@param aLogCalc, array, Array que deve ser preenchido com a mensagem do log
@param cTexto, characters, Texto que deve ser apresentado no log
@type function
/*/
Static Function FiltraLog(aLogCalc, cTexto)
Local nPos := 0

If Len(Alltrim(cTexto)) >= 210
	nPos := At(" ",cTexto,200)
	If nPos > 0
		aAdd(aLogCalc, substr(cTexto,1,nPos))
		aAdd(aLogCalc, substr(cTexto,nPos))
	Else
		aAdd(aLogCalc, substr(cTexto,1,209))
		aAdd(aLogCalc, substr(cTexto,210))
	EndIf
Else
	aAdd(aLogCalc, cTexto)
EndIf

Return( NIL )

/*/{Protheus.doc} fGeraApiTk
//Função para gerar o API Token 
@author marco.nakazawa
@since 26/08/2020
@version 1.0
@return NIL
@param URL Carol, Access Token, Conector Id, Organização
@type function
/*/
Static Function fGeraApiTk( ccURL, cAccesTokn, cConecId, cOrg)
Local aHeader	:= {}
Local cPath		:= ""
Local cParams	:= ""
Local cRet		:= ""
Local oClient	:= Nil
Local oObj		:= Nil
Local oRet		:= JsonObject():New()

Default ccURL		:= ""
Default cAccesTokn	:= ""
Default cConecId	:= ""
Default cOrg	:= ""

	If !Empty(cAccesTokn) .And. !Empty(cConecId) .And. !Empty(ccURL) .And. !Empty(cOrg)
		cPath	:= "/api/v1/apiKey/issue"
		cParams := "connectorId=" + cConecId + "&
		cParams += "description=%7B%22en-US%22%3A%22API%20Token%20Protheus%22%7D"

		aAdd( aHeader, "Accept: application/json" )
		aAdd( aHeader, "Authorization:" + cAccesTokn )
		aAdd( aHeader, "Content-type: application/x-www-form-urlencoded" )
		aAdd( aHeader, "Origin:" + ccURL )
		aAdd( aHeader, "Referer:" + ccURL + "/" + cOrg + "/carol-ui/environment/connector-tokens" )

		oClient := FwRest():New(ccURL)
		oClient:SetPath(cPath)
		oClient:SetPostParams(cParams)
		oClient:Post(aHeader)
		
		If FWJsonDeserialize(oClient:GetResult(),@oObj)
			If oObj <> Nil
				cRet := oClient:GetResult()
				If oRet:fromJson(cRet) == Nil .And. oRet["errorCode"] == Nil
					PutMv("MV_APICLOA",oRet["X-Auth-Key"])
					lGeraTokn := .T.
				EndIf
			EndIf
		EndIf
	EndIf
Return

/*/{Protheus.doc} fAddMarc
//Função para adicionar marcações no array para posterior gravação 
@author allyson.mesashi
@since 14/01/2021
@version 1.0
@return NIL
@type static function
/*/
Static Function fAddMarc( oJson, aMarcac, nUltNSR )

Local aTemp		:= {}
Local nCoutRegs	:= 0

For nCoutRegs:= 1 to Len(oJson["hits"])			
	If !Empty( oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["piscode"] )					
		aTemp   := {oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["piscode"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["nsrcode"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["mdmeventdate"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["eventdatestr"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["mdmpersonid"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["mdmname"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["devicedescription"],;
					oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["eventdatestr"]}
		nUltNSR := oJson["hits"][nCoutRegs]["mdmGoldenFieldAndValues"]["nsrcode"]
		aAdd(aMarcac,aTemp)					
	EndIf				
Next nCoutRegs

Return
