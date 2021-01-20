#INCLUDE "TOTVS.CH"
#INCLUDE "APWEBSRV.CH"
#INCLUDE "RESTFUL.CH"
#INCLUDE "FILEIO.CH"

Function APICAROL01()
Return .T.

WSRESTFUL IntegrationCarolClockin DESCRIPTION "Integração com Carol Clock in"

	WSDATA WsNull		As String Optional
	WSDATA type			As String Optional
	WSDATA filter		As String Optional
	WSDATA page       	As String Optional
	WSDATA pageSize   	As String Optional	
	
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
