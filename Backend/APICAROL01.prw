#INCLUDE "TOTVS.CH"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "RESTFUL.CH"
#INCLUDE "FILEIO.CH"

#DEFINE PAGESIZE_DEFAULT 5
#DEFINE PAGE_DEFAULT     1

Function APICAROL01()
Return .T.

WSRESTFUL IntegrationCarolClockin DESCRIPTION "Integração com Carol Clock in"

	WSDATA filter		As String Optional
	WSDATA companyId	 As String
	WSDATA branchId	     As String
	WSDATA page			 As Integer Optional
	WSDATA pageSize		 As Integer Optional

	WSMETHOD GET fConfigured ;
	 DESCRIPTION "Sistema está configurado para a integração?";
	 WSSYNTAX "/config/configured" ;
	 PATH "/config/configured" ; 
	 PRODUCES 'application/json;charset=utf-8'

	WSMETHOD GET fParameters ;
	 DESCRIPTION "Retorna parametros de integração";
	 WSSYNTAX "/config" ;
	 PATH "/config" ; 
	 PRODUCES 'application/json;charset=utf-8'

	WSMETHOD PUT fSaveConfig ;
	 DESCRIPTION "Salva configurações";
	 WSSYNTAX "/config" ;
	 PATH "/config" ; 
	 PRODUCES 'application/json;charset=utf-8'

	WSMETHOD GET fDevices ;
	 DESCRIPTION "Retorna lista de dispositivos cadastrados na Carol Clock In ";
	 WSSYNTAX "/devices" ;
	 PATH "/devices" ; 
	 PRODUCES 'application/json;charset=utf-8'

	WSMETHOD GET fTotalMarkings ;
	 DESCRIPTION "Retorna lista total de marcações pendentes dos dispositivos cadastrados na Carol Clock In ";
	 WSSYNTAX "/devices/markings" ;
	 PATH "/devices/markings" ; 
	 PRODUCES 'application/json;charset=utf-8'

	WSMETHOD POST fLoadMarkings ;
	 DESCRIPTION "Efetua carga das marcações na Carol Clock In por dispositivo";
	 WSSYNTAX "/loadMarkings" ;
	 PATH "/loadMarkings" ; 
	 PRODUCES 'application/json;charset=utf-8'

END WSRESTFUL

WSMETHOD GET fConfigured WSREST IntegrationCarolClockin

Local cJsonObj   := "JsonObject():New()"
Local oItem      := &cJsonObj
Local lAtivo	 := GetMv("MV_APICLO0", NIL , .F.)
Local lConfig	 := !Empty(GetMv("MV_APICLO1", NIL , .F.))

oItem["configured "] := lAtivo .and. lConfig
cJson := FWJsonSerialize(oItem, .F., .F., .T.)
Self:SetResponse(cJson)

Return( .t. )

WSMETHOD GET fParameters WSREST IntegrationCarolClockin

Local cJsonObj   := "JsonObject():New()"
Local oItem      := &cJsonObj

oItem["ActiveIntegration"] := GetMv("MV_APICLO0", NIL , .F.)
oItem["EndPointUrl"] := GetMv("MV_APICLO1", NIL , .F.)
oItem["EndPointPath"] := GetMv("MV_APICLO2", NIL , .F.)
oItem["ConnectionId"] := GetMv("MV_APICLO3", NIL , .F.)
oItem["EndPointUserName"] := GetMv("MV_APICLO4", NIL , .F.)
oItem["EndPointPassword"] := GetMv("MV_APICLO5", NIL , .F.)
oItem["EndPointDomainName"] := GetMv("MV_APICLO6", NIL , .F.)
oItem["EndPointPathDeviceList"] := GetMv("MV_APICLO7", NIL , .F.)
oItem["EndPointPathRecordList"] := GetMv("MV_APICLO8", NIL , .F.)
oItem["OrganizationName"] := GetMv("MV_APICLO9", NIL , .F.)
oItem["ApiToken"] := GetMv("MV_APICLOA", NIL , .F.)
oItem["MV_APICLOB"] := GetMv("MV_APICLOB", NIL , .F.)

cJson := FWJsonSerialize(oItem, .F., .F., .T.)
Self:SetResponse(cJson)

Return( .t. )

WSMETHOD PUT fSaveConfig WSREST IntegrationCarolClockin

Local cJsonObj   := "JsonObject():New()"
Local cBody	     := ::GetContent()
Local oItem      := &cJsonObj
oItem:FromJson(cBody)

If oItem != Nil  .and. Len(oItem:GetNames()) == 0  
	SetRestFault(400,EncodeUTF8(NoAcento(OemToAnsi("Parâmetros inválidos"))))
	return (.F.)
EndIf

PutMv("MV_APICLO0", oItem["ActiveIntegration"])
PutMv("MV_APICLO1", oItem["EndPointUrl"])
PutMv("MV_APICLO2", oItem["EndPointPath"])
PutMv("MV_APICLO3", oItem["ConnectionId"])
PutMv("MV_APICLO4", oItem["EndPointUserName"])
PutMv("MV_APICLO5", oItem["EndPointPassword"])
PutMv("MV_APICLO6", oItem["EndPointDomainName"])
PutMv("MV_APICLO7", oItem["EndPointPathDeviceList"])
PutMv("MV_APICLO8", oItem["EndPointPathRecordList"])
PutMv("MV_APICLO9", oItem["OrganizationName"])
PutMv("MV_APICLOA", oItem["ApiToken"])
PutMv("MV_APICLOB", oItem["MV_APICLOB"])
cJson := FWJsonSerialize(oItem, .F., .F., .T.)
::SetResponse(cJson)

Return( .t. )

WSMETHOD GET fDevices WSRECEIVE page, pageSize, filter WSREST IntegrationCarolClockin
Local cJsonObj   := "JsonObject():New()"
Local oItem      := &cJsonObj
Local aItem		 := {}
Local oRet		 := &cJsonObj
Local nI 		 := 0
Local adados 	 := {}
Local aDisps  	 := {}
Local nInicio	 := 0
Local nTotalDisp := 0
Local nTotal     := 0
Local oCount	 := &cJsonObj

Private aLog		:= { {} }
Private lApiToken	:= .F.
Private lGeraTokn	:= .F.
Private lTemRR1		:= .F.

DEFAULT Self:page 		:= PAGE_DEFAULT
DEFAULT Self:pageSize 	:= PAGESIZE_DEFAULT

If Self:page > 1
	nInicio := (Self:page * Self:pageSize) - Self:pageSize
EndIf
aDisps := fDispBusc(Self:Filter, nInicio, Self:pageSize)

If !aDisps[1]
	SetRestFault(404,EncodeUTF8(NoAcento(OemToAnsi("Erro de comunicação com Carol Clock in"))))
	Return .F.
EndIf

nTotalDisp := Len(aDisps[3])
If Empty(nTotalDisp)
	SetRestFault(404,EncodeUTF8(NoAcento(OemToAnsi("Dispositivos não cadastrados"))))
	Return .F.
EndIf

oCount:fromJson(aDisps[2])
nTotal := oCount["totalHits"]
For nI := 1 to nTotalDisp
	aDados := fMarcBusc(aDisps[3][nI][1],,,.F.,,.T.)
	If aDados[1]
		oItem  := &cJsonObj
		oItem["deviceCode"] := aDisps[3][nI][1]
		oItem["deviceDescription"] := aDisps[3][nI][2]
		oItem["count"] := aDados[4]
		aadd(aItem,oItem)
	EndIf
Next	

oRet["hasNext"] :=(Self:page * Self:pageSize) < nTotal
oRet["items"] := aItem

cJson := FWJsonSerialize(oRet, .F., .F., .T.)
Self:SetResponse(cJson)

Return( .t. )

WSMETHOD GET fTotalMarkings WSREST IntegrationCarolClockin
Local oRet		 := JsonObject():New()
Local nI 		 := 0
Local adados 	 := {}
Local aDisps  	 := {}
Local nTotalMarc := 0

Private aLog		:= { {} }
Private lApiToken	:= .F.
Private lGeraTokn	:= .F.
Private lTemRR1		:= .F.

aDisps := fDispBusc()

If Empty(aDisps)
	SetRestFault(404,EncodeUTF8(NoAcento(OemToAnsi("Dispositivos não cadastrados"))))
	Return .F.
EndIf

For nI := 1 to Len(aDisps)
	aDados := fMarcBusc(aDisps[3][nI][1],,,.F.,,.T.)
	If aDados[1]
		nTotalMarc += aDados[4]
	EndIf
Next	

oRet["total"] := nTotalMarc

cJson := FWJsonSerialize(oRet, .F., .F., .T.)
Self:SetResponse(cJson)

Return( .t. )

WSMETHOD POST fLoadMarking WSREST IntegrationCarolClockin

Local aDados		:= {}
Local aDisps		:= {}
Local aResp			:= {}
Local cBody	    	:= self:GetContent()
Local cJson	    	:= ""
Local nI			:= 0
Local oParams   	:= JsonObject():New()
Local oResp     	:= JsonObject():New()
Local oRet     		:= JsonObject():New()

Private lApiToken	:= .F.
Private lTemRR1		:= AliasInDic("RR1")

oParams:FromJSON( cBody )

If Empty( oParams["devices"] )
	SetRestFault(404,EncodeUTF8(NoAcento(OemToAnsi("Dispositivos não informados"))))
	Return .F.
EndIf

aDisps := oParams["devices"]

For nI := 1 to Len(aDisps)
	cTempDisp 	:= aDisps[nI]["deviceCode"]
	aDados 		:= fMarcBusc(cTempDisp,,,.F.,)
	oResp     	:= JsonObject():New()
	If aDados[1] .And. Len(aDados[3]) > 0		
		fProcessa( cTempDisp, aDados[3], .T., .F. )
		oResp["deviceCode"] 	:= cTempDisp
		oResp["message"] 		:= "Importado"
		oResp["status"]			:= "200"
		aAdd( aResp, oResp )
	Else
		oResp["deviceCode"] 	:= cTempDisp
		oResp["message"] 		:= "Falha na importação ou sem marcações para importar"
		oResp["status"]			:= "400"
		aAdd( aResp, oResp )
	EndIf
Next	

oRet["devices"] := aResp

cJson := FWJsonSerialize(oRet, .F., .F., .T.)
Self:SetResponse(cJson)

Return( .t. )
