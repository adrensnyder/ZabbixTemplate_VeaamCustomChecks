;###################################################################
;# Copyright (c) 2023 AdrenSnyder https://github.com/adrensnyder
;#
;# Permission is hereby granted, free of charge, to any person
;# obtaining a copy of this software and associated documentation
;# files (the "Software"), to deal in the Software without
;# restriction, including without limitation the rights to use,
;# copy, modify, merge, publish, distribute, sublicense, and/or sell
;# copies of the Software, and to permit persons to whom the
;# Software is furnished to do so, subject to the following
;# conditions:
;#
;# The above copyright notice and this permission notice shall be
;# included in all copies or substantial portions of the Software.
;#
;# DISCLAIMER:
;# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
;# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
;# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
;# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
;# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
;# OTHER DEALINGS IN THE SOFTWARE.
;###################################################################

#AutoIt3Wrapper_Res_Description=VeeamCustomChecks
#AutoIt3Wrapper_Res_Fileversion=1.0
#AutoIt3Wrapper_Res_ProductVersion=
#AutoIt3Wrapper_Res_Language=
#AutoIt3Wrapper_Res_LegalCopyright=Created by AdrenSnyder

#include <File.au3>
#include <Array.au3>
#include <Constants.au3>
#include <Date.au3>
#include <ADO.au3>
#AutoIt3Wrapper_Change2CUI=y
#RequireAdmin

#Region Globals
Global $vDefaultConf[2]
Global $ConfString = ""
Global $vDefaultConf_Size

Global $LogName = ""
Global $LogDir = ""
Global $LogFile = ""

Global $JsonName = ""
Global $JsonDir = ""
Global $JsonFile = ""

Global $ConfName = ""
Global $ConfDir = ""
Global $ConfFile = ""

Global $ZabbixDataFile = ""
Global $vZabbix_Conf = ""
Global $vZabbix_Sender_Exe = ""
Global $Zabbix_Items = ""

Global $ZabbixBasePath = "c:\zabbix_agent"

Global $DataErrors = ""

Global $BackupCount = 0
Global $ReplicaCount = 0
Global $AgentCount = 0
Global $GuestCount = 0

Global $Array_Disc = ""
Global $Array_Disc_Tmp = ""
Global $Comma = ""

Global $sConnectionString
Global $oConnection
Global $Debug = 0
Global $sDriver = ""
Global $sDatabase = ""
Global $sServer = ""
Global $sPort = ""
Global $sUID = ""
Global $sPWD = ""

Global $AgentEnabled = 0
#EndRegion Globals

#Region Check Parameters
For $i = 1 To $CmdLine[0]
    Switch $CmdLine[$i]
		Case StringLeft($CmdLine[$i], 8 ) = "--debug="
            $Debug = StringTrimLeft($CmdLine[$i], 8)
		Case StringLeft($CmdLine[$i], 9) = "--driver="
            $sDriver = StringTrimLeft($CmdLine[$i], 9)
        Case StringLeft($CmdLine[$i], 11) = "--database="
            $sDatabase = StringTrimLeft($CmdLine[$i], 11)
		Case StringLeft($CmdLine[$i], 9) = "--server="
            $sServer = StringTrimLeft($CmdLine[$i], 9)
		Case StringLeft($CmdLine[$i], 7) = "--port="
            $sPort = StringTrimLeft($CmdLine[$i], 7)
		Case StringLeft($CmdLine[$i], 7) = "--user="
            $sUID = StringTrimLeft($CmdLine[$i], 7)
		Case StringLeft($CmdLine[$i], 11) = "--password="
            $sPWD = StringTrimLeft($CmdLine[$i], 11)
		Case StringLeft($CmdLine[$i], 8) = "--agent="
            $AgentEnabled = StringTrimLeft($CmdLine[$i], 8)
	EndSwitch
Next

if ($sDriver = "" or $sDatabase = "" or $sServer = "") then
	ConsoleWrite(@CRLF & "Error: Missing parameters")

	$msg_usage = "Usage:" & @CRLF & _
	"--debug=[0/1] [Default 0]: enable or disable the debug" & @CRLF & _
	"--driver=[string]: ODBC Driver name. ['SQL Server' for MS SQL. 'PostgreSQL ANSI' or 'PostgreSQL Unicode' for PostgreSQL'" & @CRLF & _
	"--server=[string]: Instance and server [Ex. MS SQL: localhost\VEEAMSQL PostgreSQL: localhost]" & @CRLF & _
	"--port=[string]: Port if required. For PostgreSQL is 5432. Not needed usually for MS SQL" & @CRLF & _
	"--database=[string]: Database Name" & @CRLF & _
	"--user=[string]: Username if needed. Per PostgreSQL the default is 'postgres'" & @CRLF & _
	"--password[string]: Password if needed" & @CRLF & _
	"--agents[string]: Enable agents monitoring (Probably pc backup)"

	ConsoleWrite(@CRLF & @CRLF & $msg_usage)

	exit
EndIf
#EndRegion Check Parameters

#Region Files Handling
; Log
$LogName = @ScriptName & ".log"
$LogDir = $ZabbixBasePath & "\log"
$LogFile = $LogDir & "\" & $LogName

if Not FileExists($LogDir) Then
	DirCreate($LogDir)
endif

if FileExists($LogFile) then
	FileDelete($LogFile)
endif

FileDelete($LogFile)

; Json
$JsonName = @ScriptName & ".json"
$JsonDir = $ZabbixBasePath & "\data_apps"
$JsonFile = $JSONDIR & "\" & $JsonName

if Not FileExists($JSONDIR) Then
	DirCreate($JSONDIR)
endif

FileDelete($JsonFile)

; Data file for zabbix
$ZabbixDataFile = $JSONDIR & "\" & @ScriptName & ".data"

if FileExists($ZabbixDataFile) then
	FileDelete($ZabbixDataFile)
endif

; Conf File
$ConfName = @ScriptName & ".conf"

$ConfDir = $ZabbixBasePath & "\data_apps"
$ConfFile = $ConfDir & "\" & $ConfName

if Not FileExists($ConfDir) Then
	DirCreate($ConfDir)
endif
#EndRegion Files Handiling

#Region Errors Handler
Local $oErrorHandler = ObjEvent("AutoIt.Error", "_ErrFunc")
Func _ErrFunc($oError)
	local $errmsg = @CRLF & "err.number is: " & @TAB & $oError.number & @CRLF & _
            "err.windescription:" & @TAB & $oError.windescription & @CRLF & _
            "err.description is: " & @TAB & $oError.description & @CRLF & _
            "err.source is: " & @TAB & $oError.source & @CRLF & _
            "err.helpfile is: " & @TAB & $oError.helpfile & @CRLF & _
            "err.helpcontext is: " & @TAB & $oError.helpcontext & @CRLF & _
            "err.lastdllerror is: " & @TAB & $oError.lastdllerror & @CRLF & _
            "err.scriptline is: " & @TAB & $oError.scriptline & @CRLF & _
            "err.retcode is: " & @TAB & $oError.retcode & @CRLF & @CRLF
	_logmsg($LogFile,$errmsg,true,true)
EndFunc   ;==>_ErrFunc

; Internal ADO.au3 UDF COMError Handler
_ADO_ComErrorHandler_UserFunction(_ADO_COMErrorHandler_Function)
#EndRegion Errors Handler

#Region Configuration
; Default conf
$vDefaultConf[1] = "Veeam Custom Checks Configuration"
$ConfString = "# Zabbix_Sender.exe Position"
$ConfString &= "|" & "zabbix_sender_Var=c:\zabbix_agent\zabbix_sender.exe"
$ConfString &= "|" & ""
$ConfString &= "|" & "# Zabbix Configuration File"
$ConfString &= "|" & "zabbix_conf_Var=c:\zabbix_agent\data_apps\zabbix_agentd.win.conf"

_ArrayAdd($vDefaultConf,$ConfString)
$vDefaultConf_Size = Ubound($vDefaultConf) - 1

; Load Conf
if FileExists($ConfFile) = false then
	Local $hFileOpen = FileOpen($ConfFile, $FO_APPEND)
	If $hFileOpen = -1 Then
		MsgBox($MB_SYSTEMMODAL, "", "Configuration file cannot be opened", 10)
	EndIf

	for $i = 1 to $vDefaultConf_Size step 1
		FileWriteLine($hFileOpen,$vDefaultConf[$i])
	Next

	FileClose($hFileOpen)

	_logmsg($LogFile,"New configuration file created",true,true)
endif

For $i = 1 to _FileCountLines($ConfFile)
	$line = FileReadLine($ConfFile, $i)
	;msgbox (0,'','the line ' & $i & ' is ' & $line)
	$vResult = StringSplit($line,"=")
	;msgbox (0,'','the line ' & $i & ' is ' & $vResult)
    if $vResult[0] > 1 then
		Select
			Case StringInStr($vResult[1],"zabbix_conf_Var")
				$vZabbix_Conf = $vResult[2]
			Case StringInStr($vResult[1],"zabbix_sender_Var")
				$vZabbix_Sender_Exe = $vResult[2]
		endselect
	endif
Next
#EndRegion Configuration

#Region Main Function
_VeeamDataSearch()

Func _VeeamDataSearch()

	$result = _SQLConnection()
	if $result <> 0 then
		_logmsg($LogFile,"Connection Error",true,true)
		exit
	EndIf

	; SQL MS SQL - RepositoryId
	$sql_repositoryid = "WITH DistinctRepo AS ( " & _
		"SELECT " & _
		"		object_name,status,creation_time,end_time,CAST(reason AS NVARCHAR(255)) AS reason, " & _
		"		CAST(work_details AS NVARCHAR(MAX)) AS work_details_text, " & _
		"		x.value('(RepositoryId)[1]', 'NVARCHAR(MAX)') AS repo_id, " & _
		"		ROW_NUMBER() OVER (PARTITION BY object_name, x.value('(RepositoryId)[1]', 'NVARCHAR(MAX)') ORDER BY end_time DESC) AS rn " & _
		"	FROM dbo.[Backup.Model.BackupTaskSessions] " & _
		"	CROSS APPLY work_details.nodes('/*') AS T(x) " & _
		"	WHERE x.exist('(RepositoryId)[1]') = 1 " & _
		") " & _
		"SELECT " & _
		"	object_name,status,creation_time,end_time,reason,work_details_text " & _
		"FROM DistinctRepo " & _
		"WHERE rn = 1;"

	; SQL MS SQL - hostDnsName Replica
	$sql_hostdnsname = "WITH DistinctHost AS ( " & _
		"SELECT " & _
		"	 object_name,status,creation_time,end_time,CAST(reason AS NVARCHAR(255)) AS reason, " & _
		"    CAST(work_details AS NVARCHAR(MAX)) AS work_details_text, " & _
		"    x.value('(@hostDnsName)[1]', 'NVARCHAR(MAX)') AS host_dns_name, " & _
		"    ROW_NUMBER() OVER (PARTITION BY object_name, x.value('(@hostDnsName)[1]', 'NVARCHAR(MAX)') ORDER BY end_time DESC) AS rn " & _
		"FROM dbo.[Backup.Model.BackupTaskSessions] " & _
		"CROSS APPLY work_details.nodes('//HvDataStorage') AS T(x) " & _
		"WHERE x.exist('(@hostDnsName)') = 1 " & _
		") " & _
		"SELECT " & _
		"	object_name,status,creation_time,end_time,reason,work_details_text " & _
		"FROM DistinctHost " & _
		"WHERE rn = 1;"

	$sql_agents = "WITH RankedTasks AS ( " & _
		"	SELECT " & _
		"		object_name,status,creation_time,end_time,CAST(reason AS VARCHAR(255)) AS reason,work_details, " & _
		"		ROW_NUMBER() OVER (PARTITION BY object_name ORDER BY end_time DESC) AS rn " & _
		"	FROM dbo.[Backup.Model.BackupTaskSessions] " & _
		"	WHERE " & _
		"		work_details.exist('//RepositoryId') = 0 " & _
		"		AND work_details.exist('//*[@hostDnsName]') = 0 " & _
		"		AND work_details.exist('//Item[@OibId]') = 1 " & _
		") " & _
		"SELECT " & _
		"	object_name,status,creation_time,end_time,reason,work_details " & _
		"FROM RankedTasks " & _
		"WHERE rn = 1;"

	; SQL PostgreSQL
	If StringInStr($sDriver,"PostgreSQL") then
		; RepositoryId
		$sql_repositoryid = "WITH DistinctRepo AS (SELECT " & _
			"	object_name,status,creation_time,end_time,CAST(reason AS VARCHAR(255)) AS reason, " & _
			"	xmlserialize(content work_details as text) AS work_details_text, " & _
			"	xmlserialize(content (xpath('//RepositoryId/text()', work_details))[1] as text) AS repo_id, " & _
			"	ROW_NUMBER() OVER (PARTITION BY object_name, xmlserialize(content (xpath('//RepositoryId/text()', work_details))[1] as text) ORDER BY end_time DESC) AS rn " & _
			"FROM public." & chr(34) & "backup.model.backuptasksessions" & chr(34) & " " & _
			"WHERE array_length(xpath('//RepositoryId/text()', work_details), 1) > 0 " & _
			") " & _
			"SELECT " & _
			"	object_name,status,creation_time,end_time,reason,work_details_text " & _
			"FROM DistinctRepo " & _
			"WHERE rn = 1;"

		; hostDnsName Replica
		$sql_hostdnsname = "WITH DistinctHost AS ( " & _
			"	SELECT " & _
			"		object_name,status,creation_time,end_time,CAST(reason AS VARCHAR(255)) AS reason, " & _
			"		xmlserialize(content work_details as text) AS work_details_text, " & _
			"		xmlserialize(content (xpath('//HvDataStorage/@hostDnsName', work_details))[1] as text) AS host_dns_name, " & _
			"		ROW_NUMBER() OVER (PARTITION BY object_name, xmlserialize(content (xpath('//HvDataStorage/@hostDnsName', work_details))[1] as text) ORDER BY end_time DESC) AS rn " & _
			"	FROM public." & chr(34) & "backup.model.backuptasksessions" & chr(34) & " " & _
			"	WHERE array_length(xpath('//HvDataStorage/@hostDnsName', work_details), 1) > 0 " & _
			") " & _
			"SELECT " & _
			"	object_name,status,creation_time,end_time,reason,work_details_text " & _
			"FROM DistinctHost " & _
			"WHERE rn = 1;"

		$sql_agents = "WITH RankedTasks AS ( " & _
			"	SELECT " & _
			"		object_name,status,creation_time,end_time,CAST(reason AS VARCHAR(255)) AS reason,work_details, " & _
			"		ROW_NUMBER() OVER (PARTITION BY object_name ORDER BY end_time DESC) AS rn " & _
			"	FROM public." & chr(34) & "backup.model.backuptasksessions" & chr(34) & " " & _
			"	WHERE " & _
			"		NOT EXISTS ( " & _
			"			SELECT 1 " & _
			"			FROM unnest(xpath('//RepositoryId', work_details)) AS x " & _
			"		) " & _
			"		AND " & _
			"		NOT EXISTS ( " & _
			"			SELECT 1 " & _
			"			FROM unnest(xpath('//*[@hostDnsName]', work_details)) AS x " & _
			"		) " & _
			"			AND EXISTS ( " & _
			"			SELECT 1 " & _
			"			FROM unnest(xpath('//Item[@OibId]', work_details)) AS x " & _
			"		) " & _
			") " & _
			"SELECT " & _
			"	object_name,status,creation_time,end_time,reason,work_details " & _
			"FROM RankedTasks " & _
			"WHERE rn = 1;"
	EndIf

	$Array_Disc = "{" & chr(34) & "data" & chr(34) & ":["
	$Array_Disc_Tmp = ""
	$Comma = ""

	_SqlRetrieveData("RepositoryId",$sql_repositoryid)
	_SqlRetrieveData("hostDnsName",$sql_hostdnsname)
	_SqlRetrieveData("Agents",$sql_agents)

	$Array_Disc &= $Array_Disc_Tmp & "]}"

	; Add DataErrors to zabbix data
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.dataerrors",$DataErrors)

	; Send discovery data to Zabbix
	_logmsg($LogFile,"Zabbix - Discovery",false,true)
	FileWrite($JsonFile, " - backup.veeam.customchecks.discovery " & $array_disc)
	$ZabbixSend = $vZabbix_Sender_Exe & " -vv -c " & $vZabbix_Conf & " -i " & $JsonFile
	RunWait($ZabbixSend,$ZabbixBasePath,@SW_HIDE)

	; Jobs Count
	_logmsg($LogFile,"Zabbix - Guest Count",false,true)
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.guest.count",$GuestCount)
	_logmsg($LogFile,"Zabbix - Backup Count",false,true)
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.type.backup.count",$BackupCount)
	_logmsg($LogFile,"Zabbix - Replica Count",false,true)
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.type.replica.count",$ReplicaCount)
	_logmsg($LogFile,"Zabbix - Agent Count",false,true)
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.type.agent.count",$AgentCount)

	; Send data to Zabbix
	_logmsg($LogFile,"Zabbix - Data",false,true)
	FileWrite($ZabbixDataFile, $Zabbix_Items)
	$ZabbixSend = $vZabbix_Sender_Exe & " -vv -c " & $vZabbix_Conf & " -i " & $ZabbixDataFile
	RunWait($ZabbixSend,$ZabbixBasePath,@SW_HIDE)

	; CleanUp
	$oRecordset = Null
	_ADO_Connection_Close($oConnection)
	$oConnection = Null

EndFunc
#EndRegion Main Function

#Region Functions
; Connection to SQL
Func _SQLConnection()
	Local $port_string = ""
	If $sPort <> "" then
		$port_string = 'PORT=' & $sPort & ';'
	EndIf

	$sConnectionString = 'DRIVER={' & $sDriver & '};SERVER=' & $sServer & ';DATABASE=' & $sDatabase & ';UID=' & $sUID & ';PWD=' & $sPWD & ';' & $port_string

	$oConnection = _ADO_Connection_Create()
	_logmsg($LogFile,"Connection to " & $sDriver,false,true)

	If $Debug = 1 Then
		_logmsg($LogFile,"ConnectionString: " & $sConnectionString,true,true)
	EndIf

	; Connection to SQL
	_ADO_Connection_OpenConString($oConnection, $sConnectionString)

	If @error Then
		_logmsg($LogFile,"Connection Error: " & @error,true,true)
		Return SetError(@error, @extended, $ADO_RET_FAILURE)
	EndIf
EndFunc

Func _SqlRetrieveData($TargetType,$sql)

	_logmsg($LogFile,"Retrieve Data - " & $TargetType,false,true)

	Local $oRecordset = _ADO_Execute($oConnection,$sql)
	If @error Then
		_logmsg($LogFile,"Retrieve data error: " & @error,true,true)
		Return SetError(@error, @extended, $ADO_RET_FAILURE)
	EndIf

	If $Debug = 1 Then
		_logmsg($LogFile,"SQL: " & $sql,true,true)
	EndIf

	Local $aRecordsetArray = _ADO_Recordset_ToArray($oRecordset, False)
	Local $aRecordset_inner = _ADO_RecordsetArray_GetContent($aRecordsetArray)

	Local $iColumn_count = UBound($aRecordset_inner, $UBOUND_COLUMNS)

	For $iRecord_idx = 0 To UBound($aRecordset_inner) - 1
		if $iColumn_count = 6 then

			Local $MonitorEnabled = 0
			Local $ObjName = $aRecordset_inner[$iRecord_idx][0]
			Local $Status = $aRecordset_inner[$iRecord_idx][1]
			Local $Reason = $aRecordset_inner[$iRecord_idx][4]

			Local $WorkDetails = $aRecordset_inner[$iRecord_idx][5]

			Local $Target = ""
			Local $tag = ""
			If $TargetType = "RepositoryId" Then
				$Target = _GetRepositoryName($WorkDetails)
				$tag = "R"
				$BackupCount += 1
				$MonitorEnabled = 1
			EndIf
			If $TargetType = "hostDnsName" Then
				$Target = _XMLExtractValue($WorkDetails,"//HvDataStorage/@hostDnsName")
				$tag = "D"
				$ReplicaCount += 1
				$MonitorEnabled = 1
			EndIf
			If $TargetType = "Agents" Then
				$Target = "N/A"
				$tag = "A"
				$AgentCount += 1
				$MonitorEnabled = $AgentEnabled
			EndIf

			If $Target = "" Then
				$DataErrors &= $ObjName & "(" & $TargetType & ") with no target " & @CR
				_logmsg($LogFile,"DataErrors: " & $DataErrors & @CRLF & "XML: " & $WorkDetails,true,true)
				ContinueLoop
			EndIf

			$GuestCount += 1
			If $TargetType = "Agents" and $AgentEnabled = 0 then
				ContinueLoop
			EndIf

			_logmsg($LogFile,"################ Row " & $iRecord_idx,true,true)

			$Target &= "(" & $tag & ")"

			Local $CreationTime = $aRecordset_inner[$iRecord_idx][2]
			Local $CreationTime_Date = _DateVeeamFormat($CreationTime)

			Local $EndTime = $aRecordset_inner[$iRecord_idx][3]
			Local $EndTime_Date = _DateVeeamFormat($EndTime)

			Local $DateDiff = _DateDiff('D',$EndTime_Date,_NowCalc())
			Local $Duration = _DateDiff('n',$CreationTime_Date,$EndTime_Date)

			$Array_Disc_Tmp &= $Comma & "{" & chr(34) & "{#VEEAMGUEST}" & chr(34) & ":" & chr(34) & $ObjName & "" & chr(34) & "," & chr(34) & "{#VEEAMTARGET}" & chr(34) & ":" & chr(34) & $Target & "" & chr(34) & "}"
			$Comma = ","

			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.enabled[" & $ObjName & ":" & $Target & "]",$MonitorEnabled)
			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.status[" & $ObjName & ":" & $Target & "]",$Status)
			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.reason[" & $ObjName & ":" & $Target & "]",$Reason)
			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.creationtime[" & $ObjName & ":" & $Target & "]",$CreationTime_Date)
			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.endtime[" & $ObjName & ":" & $Target & "]",$EndTime_Date)
			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.datediff[" & $ObjName & ":" & $Target & "]",$DateDiff)
			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.duration[" & $ObjName & ":" & $Target & "]",$Duration)

			; Debug
			if $Debug = 1 then
				_logmsg($LogFile,"ObjName: " & $ObjName,true,true)
				_logmsg($LogFile,"Tag: " & $tag,true,true)
				_logmsg($LogFile,"Status: " & $Status,true,true)
				_logmsg($LogFile,"Reason: " & $Reason,true,true)
				_logmsg($LogFile,"WorkDetails: " & $WorkDetails,true,true)
				_logmsg($LogFile,"Target: " & $Target,true,true)
				_logmsg($LogFile,"CreationTime: " & $CreationTime_Date & "(" & $CreationTime & ")",true,true)
				_logmsg($LogFile,"EndTime: " & $EndTime_Date & "(" & $EndTime & ")",true,true)
				_logmsg($LogFile,"Duration: " & $Duration,true,true)
				_logmsg($LogFile,"DateDiff: " & $DateDiff,true,true)
			endif
		endif
	Next
EndFunc

; Convert Veeam data to usable format
Func _DateVeeamFormat($date_string)
	$date = -1

	if StringLen($date_string) = 14 then
		local $year = StringLeft($date_string,4)
		local $month = StringMid($date_string,5,2)
		local $day = StringMid($date_string,7,2)
		local $hour = StringMid($date_string,9,2)
		local $min = StringMid($date_string,11,2)
		local $sec = StringMid($date_string,13,2)
		local $date = $year & "/" & $month & "/" & $day & " " & $hour & ":" & $min & ":" & $sec
	EndIf

	Return $date
EndFunc

; Query to get repository name from id
Func _GetRepositoryName($xml)
	local $RepositoryId = ""
	Local $RepositoryName = ""

	$RepositoryId = _XMLExtractValue($xml,"//RepositoryId")

	If $RepositoryId <> "" then

		Local $sql = "SELECT name FROM dbo.[BackupRepositories] WHERE id = '" & $RepositoryId & "';"

		If StringInStr($sDriver,"PostgreSQL") then
			$sql = 'SELECT name FROM public."backuprepositories" WHERE id = ' & chr(39) & $RepositoryId & chr(39) & ';'
		EndIf

		If $Debug = 1 Then
			_logmsg($LogFile,"SQL_REPO: " & $sql,false,true)
		EndIf

		Local $oRecordset = _ADO_Execute($oConnection,$sql)
		If @error Then Return SetError(@error, @extended, $ADO_RET_FAILURE)

		Local $aRecordsetArray = _ADO_Recordset_ToArray($oRecordset, False)
		Local $aRecordset_inner = _ADO_RecordsetArray_GetContent($aRecordsetArray)

		Local $iColumn_count = UBound($aRecordset_inner, $UBOUND_COLUMNS)
		For $iRecord_idx = 0 To UBound($aRecordset_inner) - 1
			if $iColumn_count = 1 then
				If $RepositoryName = "" Then
					$RepositoryName = $aRecordset_inner[$iRecord_idx][0]
				EndIf
			EndIf
		Next
	EndIf

	$oRecordset = Null

	return $RepositoryName
EndFunc

; Extract repository id from xml
Func _XMLExtractValue($xml,$search)
	local $XMLValue = 0

	Local $oXML = ObjCreate("Microsoft.XMLDOM")
	If $oXML.loadXML($xml) Then
		if $Debug = 1 then
			_logmsg($LogFile,"XML Loaded",true,true)
			_logmsg($LogFile,"XML: " & $oXML.xml,true,true)
		EndIf

		Local $XMLNode = $oXML.SelectSingleNode($search)

		if IsObj($XMLNode) Then
			if $Debug = 1 then
				_logmsg($LogFile,"$XMLValue: " & $XMLNode.text,true,true)
			EndIf
			$XMLValue = $XMLNode.text
		else
			if $Debug = 1 then
				_logmsg($LogFile,"XML Node Not Obj ",true,true)
			EndIf
		EndIf

	else
		if $Debug = 1 then
			_logmsg($LogFile,"XML Not Loaded",true,true)
		EndIf
	EndIF

	return $XMLValue
EndFunc

; Joint items for zabbix
func _add_item_zabbix($zabbix_items,$key,$value)
	if $zabbix_items <> "" Then
		$zabbix_items &= @CRLF
	endif

	$value = StringReplace($value,@CRLF," ")
	$value = StringReplace($value,@CR," ")
	$value = StringReplace($value,@LF," ")
	;$value = RemoveControlChars($value)
	$zabbix_items = $zabbix_items & " - " & chr(34) & $key & chr(34) & " " & chr(34) & $value & chr(34)

	return $zabbix_items
endfunc

; Function to remove control characters from a string
Func RemoveControlChars($text)
    ; Define the control characters to remove
    Local $controlChars = ["\0", "\a", "\b", "\t", "\v", "\f", "\r", "\n"]
    ; Loop through each control character and replace it with an empty string
    For $i = 0 To UBound($controlChars) - 1
        $text = StringReplace($text, $controlChars[$i], "")
    Next
    Return $text
EndFunc

; Log to file/console
func _logmsg($logfile,$msg,$file = false,$console = true)
	if $file = true then
		_FileWriteLog($logfile,$msg & @CRLF)
	endif

	if $console = true Then
		ConsoleWrite($msg & @CRLF)
	endif
EndFunc
#EndRegion Functions
