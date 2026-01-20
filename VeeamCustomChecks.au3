;###################################################################
;# Copyright (c) 2025 AdrenSnyder https://github.com/adrensnyder
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
#AutoIt3Wrapper_Res_Fileversion=1.1
#AutoIt3Wrapper_Res_ProductVersion=
#AutoIt3Wrapper_Res_Language=
#AutoIt3Wrapper_Res_LegalCopyright=Created by Andrea Cariddi

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

Global $JobsCount = 0

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
Global $JobTypes = ""
Global Const $BackupConfigurationJobType = 100

#EndRegion Globals

#Region Check Parameters
For $i = 1 To $CmdLine[0]
    Switch $CmdLine[$i]
		Case StringInStr($CmdLine[$i],"--debug=") <> 0
			$Debug = GetParameter($CmdLine[$i])
		Case StringInStr($CmdLine[$i],"--driver=") <> 0
			$sDriver = GetParameter($CmdLine[$i])
        Case StringInStr($CmdLine[$i],"--database=") <> 0
			$sDatabase = GetParameter($CmdLine[$i])
		Case StringInStr($CmdLine[$i],"--server=") <> 0
			$sServer = GetParameter($CmdLine[$i])
		Case StringInStr($CmdLine[$i],"--port=") <> 0
			$sPort = GetParameter($CmdLine[$i])
		Case StringInStr($CmdLine[$i],"--user=") <> 0
			$sUID = GetParameter($CmdLine[$i])
		Case StringInStr($CmdLine[$i],"--password=") <> 0
			$sPWD = GetParameter($CmdLine[$i])
		Case StringInStr($CmdLine[$i],"--jobtypes=") <> 0
			$JobTypes = GetParameter($CmdLine[$i])
	EndSwitch
Next

Func GetParameter($string)
    Local $result = StringRegExp($string, "=(.*)", 1)

    If @error Then
        Return ""
    Else
        Return $result[0]
    EndIf
EndFunc

if ($sDriver = "" or $sDatabase = "" or $sServer = "") then
	ConsoleWrite(@CRLF & "Error: Missing parameters")

	$msg_usage = "Usage:" & @CRLF & _
	"--debug=[0/1/2] [Default 0]: (1) Display some infos, (2) Display SQL queries" & @CRLF & _
	"--driver=[string]: ODBC Driver name. ['SQL Server' for MS SQL. 'PostgreSQL ANSI' or 'PostgreSQL Unicode' for PostgreSQL'" & @CRLF & _
	"--server=[string]: Instance and server [Ex. MS SQL: localhost\VEEAMSQL PostgreSQL: localhost]" & @CRLF & _
	"--port=[string]: Port if required. For PostgreSQL is 5432. Not needed usually for MS SQL" & @CRLF & _
	"--database=[string]: Database Name" & @CRLF & _
	"--user=[string]: Username if needed. Per PostgreSQL the default is 'postgres'" & @CRLF & _
	"--password[string]: Password if needed" & @CRLF & _
	"--jobtypes=[string]: Types of backup monitored separated by ',' (0:Vm 1:Replica 4000:Agent Workstation 12000:Agent Server)"

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

	Local $result, $Result_Discovery, $Result_Data

	$result = _SQLConnection()
	if $result <> 0 then
		_logmsg($LogFile,"Connection Error",true,true)
		exit
	EndIf

	; SQL MS SQL

	Local $sql = ""
	If StringInStr($sDriver,"SQL Server") <> 0 then
		$sqldiscovery = "WITH HostsConcatenated AS (" & @CRLF & _
				"    SELECT" & @CRLF & _
				"        ij.job_id," & @CRLF & _
				"        STUFF((" & @CRLF & _
				"            SELECT '|' + o.object_name + ',' + COALESCE(o.viobject_type, 'NoType')" & @CRLF & _
				"            FROM dbo.[objectsinjobsview] ij2" & @CRLF & _
				"            JOIN dbo.[objectsview] o ON o.id = ij2.object_id" & @CRLF & _
				"            WHERE ij2.job_id = ij.job_id" & @CRLF & _
				"            FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 1, '') AS hosts" & @CRLF & _
				"    FROM dbo.[objectsinjobsview] ij" & @CRLF & _
				"    GROUP BY ij.job_id" & @CRLF & _
				")," & @CRLF & _
				"FirstSelection AS (" & @CRLF & _
				"    SELECT" & @CRLF & _
				"        CAST(j.id AS VARCHAR(255)) AS job_id," & @CRLF & _
				"        CAST(j.name AS VARCHAR(255)) AS job_name," & @CRLF & _
				"        CAST(j.repository_id AS VARCHAR(255)) AS repository_id," & @CRLF & _
				"        CAST(r.name AS VARCHAR(255)) AS repository_name," & @CRLF & _
				"        CAST(j.type AS VARCHAR(255)) AS job_type," & @CRLF & _
				"        CAST(j.is_deleted AS VARCHAR(255)) AS is_job_deleted," & @CRLF & _
				"        CAST(j.latest_result AS VARCHAR(255)) AS latest_job_result," & @CRLF & _
				"        CAST(j.schedule_enabled AS VARCHAR(255)) AS is_schedule_enabled," & @CRLF & _
				"        CAST(j.parent_job_id AS VARCHAR(255)) AS parent_job_id," & @CRLF & _
				"        CAST(j.parent_schedule_id AS VARCHAR(255)) AS parent_schedule_id," & @CRLF & _
				"        CAST(hc.hosts AS VARCHAR(255)) AS backup_hosts" & @CRLF & _
				"    FROM" & @CRLF & _
				"        dbo.[jobsview] j" & @CRLF & _
				"    LEFT JOIN" & @CRLF & _
				"        HostsConcatenated hc ON j.id = hc.job_id" & @CRLF & _
				"    LEFT JOIN" & @CRLF & _
				"        dbo.[backuprepositories] r ON j.repository_id = r.id" & @CRLF & _
				")" & @CRLF & _
				"SELECT *" & @CRLF & _
				"FROM FirstSelection" & @CRLF & _
				"WHERE " & @CRLF & _
				"    job_id NOT IN (SELECT DISTINCT parent_job_id FROM FirstSelection WHERE parent_job_id IS NOT NULL);"

		$sql = "WITH HostsConcatenated AS (" & @CRLF & _
				"    SELECT " & @CRLF & _
				"        ij.job_id, " & @CRLF & _
				"        STUFF((" & @CRLF & _
				"            SELECT '|' + o.object_name + ',' + COALESCE(o.viobject_type, 'NoType') " & @CRLF & _
				"            FROM dbo.[objectsinjobsview] ij " & @CRLF & _
				"            JOIN dbo.[objectsview] o ON o.id = ij.object_id " & @CRLF & _
				"            WHERE ij.job_id = ij.job_id " & @CRLF & _
				"            FOR XML PATH('')" & @CRLF & _
				"        ), 1, 1, '') AS hosts " & @CRLF & _
				"    FROM dbo.[objectsinjobsview] ij " & @CRLF & _
				"    GROUP BY ij.job_id " & @CRLF & _
				"), " & @CRLF & _
				"LatestBackupState AS (" & @CRLF & _
				"    SELECT " & @CRLF & _
				"        bs.job_id, " & @CRLF & _
				"        bs.job_type, " & @CRLF & _
				"        bs.state, " & @CRLF & _
				"        bs.result, " & @CRLF & _
				"        bs.reason, " & @CRLF & _
				"        bs.creation_time, " & @CRLF & _
				"        bs.end_time, " & @CRLF & _
				"        ROW_NUMBER() OVER (PARTITION BY bs.job_id ORDER BY bs.creation_time DESC) AS rn " & @CRLF & _
				"    FROM dbo.[backup.model.jobsessions] bs " & @CRLF & _
				"), " & @CRLF & _
				"LatestBackupTaskSession AS (" & @CRLF & _
				"    SELECT " & @CRLF & _
				"        bts.session_id, " & @CRLF & _
				"        bts.status, " & @CRLF & _
				"        bts.reason, " & @CRLF & _
				"        bts.creation_time, " & @CRLF & _
				"        js.job_id, " & @CRLF & _
				"        ROW_NUMBER() OVER (PARTITION BY js.job_id ORDER BY bts.creation_time DESC) AS rn " & @CRLF & _
				"    FROM dbo.[backup.model.backuptasksessions] bts " & @CRLF & _
				"    JOIN dbo.[backup.model.jobsessions] js ON bts.session_id = js.id " & @CRLF & _
				") " & @CRLF & _
				"SELECT " & @CRLF & _
				"	CAST(j.id AS VARCHAR(255)) AS job_id, " & @CRLF  & _
				"	CAST(j.name AS VARCHAR(255)) AS job_name, " & @CRLF  & _
				"	CAST(j.repository_id AS VARCHAR(255)) AS repository_id, " & @CRLF  & _
				"	CAST(r.name AS VARCHAR(255)) AS repository_name, " & @CRLF  & _
				"	CAST(j.type AS VARCHAR(255)) AS job_type, " & @CRLF  & _
				"	CAST(j.is_deleted AS VARCHAR(255)) AS is_job_deleted, " & @CRLF  & _
				"	CAST(j.latest_result AS VARCHAR(255)) AS latest_job_result, " & @CRLF  & _
				"	CAST(j.schedule_enabled AS VARCHAR(255)) AS is_schedule_enabled, " & @CRLF  & _
				"	CAST(j.parent_job_id AS VARCHAR(255)) AS parent_job_id, " & @CRLF  & _
				"	CAST(j.parent_schedule_id AS VARCHAR(255)) AS parent_schedule_id, " & @CRLF  & _
				"	CAST(hc.hosts AS VARCHAR(255)) AS backup_hosts, " & @CRLF  & _
				"	CAST(lbs.job_type AS VARCHAR(255)) AS backup_job_type, " & @CRLF  & _
				"	CAST(lbs.state AS VARCHAR(255)) AS backup_state, " & @CRLF  & _
				"	CAST(lbs.result AS VARCHAR(255)) AS backup_result, " & @CRLF  & _
				"	CAST(lbs.reason AS VARCHAR(255)) AS backup_reason, " & @CRLF  & _
				"	CAST(lbs.creation_time AS VARCHAR(255)) AS backup_creation_time, " & @CRLF  & _
				"	CAST(lbs.end_time AS VARCHAR(255)) AS backup_end_time, " & @CRLF  & _
				"	CAST(bts.status AS VARCHAR(255)) AS backup_task_status, " & @CRLF  & _
				"	CAST(bts.reason AS VARCHAR(255)) AS backup_task_reason, " & @CRLF  & _
				"	CAST(bts.session_id AS VARCHAR(255)) AS backup_task_session_id, " & @CRLF  & _
				"	CAST(j.schedule.value('(//OptionsScheduleAfterJob/IsEnabled/text())[1]', 'VARCHAR(MAX)') AS VARCHAR(255)) AS job_schedule_afterjob_enabled, " & @CRLF  & _
				"	CAST(j.schedule.value('(//OptionsDaily/Enabled/text())[1]', 'VARCHAR(MAX)') AS VARCHAR(255)) AS job_schedule_daily_enabled, " & @CRLF  & _
				"	CAST(j.schedule.value('(//OptionsDaily/Kind/text())[1]', 'VARCHAR(MAX)') AS VARCHAR(255)) AS job_schedule_daily_kind, " & @CRLF  & _
				"	CAST(STUFF(( " & @CRLF  & _
				"		SELECT ', ' + x.EMonth.value('.', 'VARCHAR(MAX)') " & @CRLF  & _
				"		FROM j.schedule.nodes('(//OptionsDaily/Days/DayOfWeek)') AS x(EMonth) " & @CRLF  & _
				"		FOR XML PATH('') " & @CRLF  & _
				"	), 1, 2, '') AS VARCHAR(255)) AS job_schedule_daily_days, " & @CRLF  & _
				"	CAST(j.schedule.value('(//OptionsPeriodically/Enabled/text())[1]', 'VARCHAR(MAX)') AS VARCHAR(255)) AS job_schedule_periodically_enabled, " & @CRLF  & _
				"	CAST(j.schedule.value('(//OptionsMonthly/Enabled/text())[1]', 'VARCHAR(MAX)') AS VARCHAR(255)) AS job_schedule_monthly_enabled, " & @CRLF  & _
				"	CAST(STUFF(( " & @CRLF  & _
				"		SELECT ', ' + x.EMonth.value('.', 'VARCHAR(MAX)') " & @CRLF  & _
				"		FROM j.schedule.nodes('(//OptionsMonthly/Months/EMonth)') AS x(EMonth) " & @CRLF  & _
				"		FOR XML PATH('') " & @CRLF  & _
				"	), 1, 2, '') AS VARCHAR(255)) AS job_schedule_monthly_months " & @CRLF  & _
				"FROM " & @CRLF & _
				"    dbo.[jobsview] j " & @CRLF & _
				"LEFT JOIN " & @CRLF & _
				"    HostsConcatenated hc ON j.id = hc.job_id " & @CRLF & _
				"LEFT JOIN " & @CRLF & _
				"    dbo.[backuprepositories] r ON j.repository_id = r.id " & @CRLF & _
				"LEFT JOIN " & @CRLF & _
				"    LatestBackupState lbs ON j.id = lbs.job_id AND lbs.rn = 1 " & @CRLF & _
				"LEFT JOIN " & @CRLF & _
				"    LatestBackupTaskSession bts ON j.id = bts.job_id AND bts.rn = 1 " & @CRLF & _
				"WHERE " & @CRLF & _
				"    bts.session_id IS NOT NULL;"
	Endif

	; SQL PostgreSQL
	If $sDriver = "PostgreSQL ANSI" then
		$sqldiscovery = "WITH HostsConcatenated AS (" & @CRLF & _
						"    SELECT" & @CRLF & _
						"        ij.job_id," & @CRLF & _
						"        STRING_AGG(o.object_name || ',' || COALESCE(o.viobject_type, 'NoType'), '|') AS hosts" & @CRLF & _
						"    FROM public." & chr(34) & "objectsinjobsview" & chr(34) & " ij " & @CRLF  & _
						"    JOIN public." & chr(34) & "objectsview" & chr(34) & " o ON o.id = ij.object_id " & @CRLF  & _
						"    GROUP BY ij.job_id" & @CRLF & _
						")," & @CRLF & _
						"FirstSelection AS (" & @CRLF & _
						"    SELECT" & @CRLF & _
						"        j.id::TEXT AS job_id," & @CRLF & _
						"        j.name::TEXT AS job_name," & @CRLF & _
						"        j.repository_id::TEXT AS repository_id," & @CRLF & _
						"        r.name::TEXT AS repository_name," & @CRLF & _
						"        j.type::TEXT AS job_type," & @CRLF & _
						"        j.is_deleted::TEXT AS is_job_deleted," & @CRLF & _
						"        j.latest_result::TEXT AS latest_job_result," & @CRLF & _
						"        j.schedule_enabled::TEXT AS is_schedule_enabled," & @CRLF & _
						"        (xpath('//JobOptionsRoot/RunManually/text()', xmlparse(document j.options)))[1]::text AS job_options_runmanually," & @CRLF & _
						"        j.parent_job_id::TEXT AS parent_job_id," & @CRLF & _
						"        j.parent_schedule_id::TEXT AS parent_schedule_id," & @CRLF & _
						"        hc.hosts::TEXT AS backup_hosts" & @CRLF & _
						"    FROM public." & chr(34) & "jobsview" & chr(34) & " j " & @CRLF  & _
						"    LEFT JOIN HostsConcatenated hc ON j.id = hc.job_id" & @CRLF & _
						"    LEFT JOIN public." & chr(34) & "backuprepositories" & chr(34) & " r ON j.repository_id = r.id " & @CRLF  & _
						")" & @CRLF & _
						"SELECT *" & @CRLF & _
						"FROM FirstSelection" & @CRLF & _
						"WHERE " & @CRLF & _
						"    job_id NOT IN (SELECT DISTINCT parent_job_id FROM FirstSelection WHERE parent_job_id IS NOT NULL);"

		$sql = "WITH HostsConcatenated AS (" & @CRLF  & _
				"    SELECT " & @CRLF  & _
				"        ij.job_id, " & @CRLF  & _
				"        string_agg(o.object_name || ',' || COALESCE(o.viobject_type, 'NoType'), '|') AS hosts " & @CRLF  & _
				"    FROM " & @CRLF  & _
				"        public." & chr(34) & "objectsinjobsview" & chr(34) & " ij " & @CRLF  & _
				"    JOIN " & @CRLF  & _
				"        public." & chr(34) & "objectsview" & chr(34) & " o ON o.id = ij.object_id " & @CRLF  & _
				"    GROUP BY " & @CRLF  & _
				"        ij.job_id " & @CRLF  & _
				"), " & @CRLF  & _
				"LatestBackupState AS (" & @CRLF  & _
				"    SELECT " & @CRLF  & _
				"        bs.job_id, " & @CRLF  & _
				"        bs.job_type, " & @CRLF  & _
				"        bs.state, " & @CRLF  & _
				"        bs.result, " & @CRLF  & _
				"        bs.reason, " & @CRLF  & _
				"        bs.creation_time, " & @CRLF  & _
				"        bs.end_time, " & @CRLF  & _
				"        ROW_NUMBER() OVER (PARTITION BY bs.job_id ORDER BY bs.creation_time DESC) AS rn " & @CRLF  & _
				"    FROM " & @CRLF  & _
				"        public." & chr(34) & "backup.model.jobsessions" & chr(34) & " bs " & @CRLF  & _
				"), " & @CRLF  & _
				"LatestBackupTaskSession AS (" & @CRLF  & _
				"    SELECT " & @CRLF  & _
				"        bts.session_id, " & @CRLF  & _
				"        bts.status, " & @CRLF  & _
				"        bts.reason, " & @CRLF  & _
				"        bts.creation_time, " & @CRLF  & _
				"        js.job_id, " & @CRLF  & _
				"        ROW_NUMBER() OVER (PARTITION BY js.job_id ORDER BY bts.creation_time DESC) AS rn " & @CRLF  & _
				"    FROM " & @CRLF  & _
				"        public." & chr(34) & "backup.model.backuptasksessions" & chr(34) & " bts " & @CRLF  & _
				"    JOIN " & @CRLF  & _
				"        public." & chr(34) & "backup.model.jobsessions" & chr(34) & " js ON bts.session_id = js.id " & @CRLF  & _
				") " & @CRLF  & _
				"SELECT " & @CRLF  & _
				"    j.id AS job_id, " & @CRLF  & _
				"    j.name AS job_name, " & @CRLF  & _
				"    j.repository_id, " & @CRLF  & _
				"    r.name AS repository_name, " & @CRLF  & _
				"    j.type AS job_type, " & @CRLF  & _
				"    j.is_deleted AS is_job_deleted, " & @CRLF  & _
				"    j.latest_result AS latest_job_result, " & @CRLF  & _
				"    j.schedule_enabled AS is_schedule_enabled, " & @CRLF  & _
				"    j.parent_job_id, " & @CRLF  & _
				"    j.parent_schedule_id, " & @CRLF  & _
				"    hc.hosts AS backup_hosts, " & @CRLF  & _
				"    lbs.job_type AS backup_job_type, " & @CRLF  & _
				"    lbs.state AS backup_state, " & @CRLF  & _
				"    lbs.result AS backup_result, " & @CRLF  & _
				"    lbs.reason AS backup_reason, " & @CRLF  & _
				"    lbs.creation_time AS backup_creation_time, " & @CRLF  & _
				"    lbs.end_time AS backup_end_time, " & @CRLF  & _
				"    bts.status AS backup_task_status, " & @CRLF  & _
				"    bts.reason AS backup_task_reason, " & @CRLF  & _
				"    bts.session_id AS backup_task_session_id, " & @CRLF  & _
				"    (xpath('//OptionsScheduleAfterJob/IsEnabled/text()', xmlparse(document j.schedule)))[1]::text AS job_schedule_afterjob_enabled, " & @CRLF  & _
				"    (xpath('//OptionsDaily/Enabled/text()', xmlparse(document j.schedule)))[1]::text AS job_schedule_daily_enabled, " & @CRLF  & _
				"    (xpath('//OptionsDaily/Kind/text()', xmlparse(document j.schedule)))[1]::text AS job_schedule_daily_kind, " & @CRLF  & _
				"    array_to_string(" & @CRLF  & _
				"        array(" & @CRLF  & _
				"            SELECT unnest(xpath('//OptionsDaily/Days/DayOfWeek/text()', xmlparse(document j.schedule)))" & @CRLF  & _
				"        ), ', ' " & @CRLF  & _
				"    ) AS job_schedule_daily_days, " & @CRLF  & _
				"    (xpath('//OptionsMonthly/Enabled/text()', xmlparse(document j.schedule)))[1]::text AS job_schedule_monthly_enabled, " & @CRLF  & _
				"    (xpath('//OptionsPeriodically/Enabled/text()', xmlparse(document j.schedule)))[1]::text AS job_schedule_periodically_enabled, " & @CRLF  & _
				"    array_to_string(" & @CRLF  & _
				"        array(" & @CRLF  & _
				"            SELECT unnest(xpath('//OptionsMonthly/Months/EMonth/text()', xmlparse(document j.schedule)))" & @CRLF  & _
				"        ), ', ' " & @CRLF  & _
				"    ) AS job_schedule_monthly_months " & @CRLF  & _
				"FROM " & @CRLF  & _
				"    public." & chr(34) & "jobsview" & chr(34) & " j " & @CRLF  & _
				"LEFT JOIN " & @CRLF  & _
				"    HostsConcatenated hc ON j.id = hc.job_id " & @CRLF  & _
				"LEFT JOIN " & @CRLF  & _
				"    public." & chr(34) & "backuprepositories" & chr(34) & " r ON j.repository_id = r.id " & @CRLF  & _
				"LEFT JOIN " & @CRLF  & _
				"    LatestBackupState lbs ON j.id = lbs.job_id AND lbs.rn = 1 " & @CRLF  & _
				"LEFT JOIN " & @CRLF  & _
				"    LatestBackupTaskSession bts ON j.id = bts.job_id AND bts.rn = 1 " & @CRLF  & _
				"WHERE " & @CRLF  & _
				"    bts.session_id IS NOT NULL;"

	EndIf

	$Array_Disc = "{" & chr(34) & "data" & chr(34) & ":["
	$Array_Disc_Tmp = ""
	$Comma = ""

	; Get jobs for discovery
	$Result_Discovery = _SqlRetrieveData($sqldiscovery)
	If IsObj($Result_Discovery) then
		DiscoveryData($Result_Discovery,$sDriver)
	else
		_logmsg($LogFile,"Error Main SQL: " & $Result_Discovery,true,true)
	Endif

	; Backup Configuration Job (PostgreSQL only)
	If $sDriver = "PostgreSQL ANSI" Then
		Local $sql_backup_config = _SqlBackupConfigurationJobPostgres()
		Local $Result_BackupConfig = _SqlRetrieveData($sql_backup_config)
		If IsObj($Result_BackupConfig) Then
			BackupConfigurationJobData($Result_BackupConfig)
		Else
			_logmsg($LogFile,"Error Backup Configuration Job SQL: " & $Result_BackupConfig,true,true)
		EndIf
	EndIf

	; Core data retrieve
	$Result_Data = _SqlRetrieveData($sql)
	If IsObj($Result_Data) then
		BackupData($Result_Data,$sDriver)
	else
		_logmsg($LogFile,"Error Main SQL: " & $Result_Data,true,true)
	Endif

	$Array_Disc &= $Array_Disc_Tmp & "]}"

	; Add DataErrors to zabbix data
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.dataerrors",$DataErrors)

	; Send discovery data to Zabbix
	_logmsg($LogFile,"Zabbix - Discovery",false,true)
	FileWrite($JsonFile, " - backup.veeam.customchecks.discovery " & $array_disc)
	$ZabbixSend = $vZabbix_Sender_Exe & " -vv -c " & $vZabbix_Conf & " -i " & $JsonFile
	RunWait($ZabbixSend,$ZabbixBasePath,@SW_HIDE)

	; Jobs Count
	_logmsg($LogFile,"Zabbix - Jobs Count",false,true)
	$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.jobs.count",$JobsCount)

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

	$TrustedConn = ""

	if stringinstr($sDriver,"SQL Server") <> 0 then
		$TrustedConn= "Trusted_Connection=Yes"
	endif

	$sConnectionString = 'DRIVER={' & $sDriver & '};SERVER=' & $sServer & ';DATABASE=' & $sDatabase & ';UID=' & $sUID & ';PWD=' & $sPWD & ';' & $port_string & ";" & $TrustedConn

	$oConnection = _ADO_Connection_Create()
	_logmsg($LogFile,"Connection to " & $sDriver,false,true)

	If $Debug = 2 Then
		_logmsg($LogFile,"ConnectionString: " & $sConnectionString,true,true)
	EndIf

	_ADO_Connection_OpenConString($oConnection, $sConnectionString)

	If @error Then
		_logmsg($LogFile,"Connection Error: " & @error & " - " & @extended & " - " & $ADO_RET_FAILURE,true,true)
		Return SetError(@error, @extended, $ADO_RET_FAILURE)
	EndIf
EndFunc

Func _SqlRetrieveData($sql)

	if $sql = "" then
		return null
	endif

	Local $oRecordset = _ADO_Execute($oConnection, $sql)
	If @error Then
		Local $sErrorDetail = ""
		If IsObj($oConnection.Errors) Then
			For $oError In $oConnection.Errors
				$sErrorDetail &= "Descrizione: " & $oError.Description & @CRLF
				$sErrorDetail &= "Numero: " & $oError.Number & @CRLF
				$sErrorDetail &= "Origine: " & $oError.Source & @CRLF
			Next
		Else
			$sErrorDetail = "Nessun dettaglio disponibile"
		EndIf

		_logmsg($LogFile, "Retrieve data error: " & @error & " - " & @extended & @CRLF & $sErrorDetail, True, True)
		Return SetError(@error, @extended, $ADO_RET_FAILURE)
	EndIf

	If $Debug = 2 Then
		_logmsg($LogFile, "SQL: " & $sql, True, True)
	EndIf

	Return $oRecordset
EndFunc

Func _IsTrueValue($value)
	If IsBool($value) Then Return $value
	Local $s = StringLower(StringStripWS(String($value), 3))
	Return ($s = "1" Or $s = "true" Or $s = "t" Or $s = "yes")
EndFunc

Func _IsFalseValue($value)
	If IsBool($value) Then Return Not $value
	Local $s = StringLower(StringStripWS(String($value), 3))
	Return ($s = "0" Or $s = "false" Or $s = "f" Or $s = "no")
EndFunc

Func _SqlBackupConfigurationJobPostgres()
	Local $sql = ""
	$sql = "WITH latest_js AS (" & @CRLF & _
		   "    SELECT" & @CRLF & _
		   "        js.id," & @CRLF & _
		   "        js.job_id," & @CRLF & _
		   "        js.job_name," & @CRLF & _
		   "        js.job_type," & @CRLF & _
		   "        js.creation_time," & @CRLF & _
		   "        js.end_time," & @CRLF & _
		   "        js.state," & @CRLF & _
		   "        js.result," & @CRLF & _
		   "        js.reason" & @CRLF & _
		   "    FROM public." & chr(34) & "backup.model.jobsessions" & chr(34) & " js" & @CRLF & _
		   "    WHERE js.job_type = " & $BackupConfigurationJobType & @CRLF & _
		   "    ORDER BY js.creation_time DESC" & @CRLF & _
		   "    LIMIT 1" & @CRLF & _
		   ")" & @CRLF & _
		   "SELECT" & @CRLF & _
		   "    js.job_id::TEXT AS job_id," & @CRLF & _
		   "    js.job_name::TEXT AS job_name," & @CRLF & _
		   "    js.job_type::TEXT AS job_type," & @CRLF & _
		   "    js.creation_time::TEXT AS creation_time," & @CRLF & _
		   "    js.end_time::TEXT AS end_time," & @CRLF & _
		   "    js.state::TEXT AS job_state," & @CRLF & _
		   "    js.result::TEXT AS job_result," & @CRLF & _
		   "    js.reason::TEXT AS job_reason," & @CRLF & _
		   "    sl.status::TEXT AS log_status," & @CRLF & _
		   "    sl.title::TEXT AS log_title," & @CRLF & _
		   "    sl." & chr(34) & "desc" & chr(34) & "::TEXT AS log_desc," & @CRLF & _
		   "    sl.starttimeutc::TEXT AS log_starttimeutc," & @CRLF & _
		   "    sl.updatetimeutc::TEXT AS log_updatetimeutc" & @CRLF & _
		   "FROM latest_js js" & @CRLF & _
		   "LEFT JOIN LATERAL (" & @CRLF & _
		   "    SELECT status, title, " & chr(34) & "desc" & chr(34) & ", starttimeutc, updatetimeutc" & @CRLF & _
		   "    FROM public.sessionlog" & @CRLF & _
		   "    WHERE sessionid = js.id" & @CRLF & _
		   "    ORDER BY updatetimeutc DESC NULLS LAST" & @CRLF & _
		   "    LIMIT 1" & @CRLF & _
		   ") sl ON true;"
	Return $sql
EndFunc

Func BackupConfigurationJobData($Recordset)
	If $Recordset.EOF Then Return

	While Not $Recordset.EOF

		Local $MonitorEnabled = 1

		Local $job_name_original = $Recordset.Fields("job_name").Value
		Local $job_name = StringReplace($job_name_original,",","_")

		Local $backup_creation_time = $Recordset.Fields("creation_time").Value
		Local $backup_creation_time_date = _DateVeeamFormat($backup_creation_time)

		Local $backup_end_time = $Recordset.Fields("end_time").Value
		Local $backup_end_time_date = _DateVeeamFormat($backup_end_time)

		Local $backup_state = $Recordset.Fields("job_state").Value
		Local $backup_result = $Recordset.Fields("job_result").Value
		Local $backup_reason = $Recordset.Fields("job_reason").Value

		Local $Duration = 0
		If $backup_end_time_date > $backup_creation_time_date Then
			$Duration = _DateDiff('n',$backup_creation_time_date,$backup_end_time_date)
		Else
			Local $duration_message = "Backup starting or in progress"
			Local $backup_reason_trim = StringStripWS(String($backup_reason), 3)
			If $backup_reason_trim = "" Or $backup_reason_trim = "\N" Then
				$backup_reason = $duration_message
			Else
				$backup_reason &= ". " & $duration_message
			EndIf
		EndIf

		Local $backup_task_status = $Recordset.Fields("log_status").Value
		Local $backup_task_reason = $Recordset.Fields("log_title").Value
		If $backup_task_reason = "" Then
			$backup_task_reason = $Recordset.Fields("log_desc").Value
		EndIf

		Local $DateDiff = _DateDiff('D',$backup_creation_time_date,_NowCalc())

		$JobsCount += 1

		$Array_Disc_Tmp &= $Comma & "{" & chr(34) & "{#VEEAMJOB}" & chr(34) & ":" & chr(34) & $job_name & "" & chr(34) & "}"
		$Comma = ","

		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.enabled[" & $job_name & "]",$MonitorEnabled)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.job.state[" & $job_name & "]",$backup_state)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.job.result[" & $job_name & "]",$backup_result)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.job.reason[" & $job_name & "]",$backup_reason)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.status[" & $job_name & "]",$backup_task_status)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.reason[" & $job_name & "]",$backup_task_reason)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.creationtime[" & $job_name & "]",$backup_creation_time_date)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.endtime[" & $job_name & "]",$backup_end_time_date)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.datediff[" & $job_name & "]",$DateDiff)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.duration[" & $job_name & "]",$Duration)

		$Recordset.MoveNext()
	WEnd
EndFunc

Func DiscoveryData($Recordset,$sDriver)
	$count = 0

	_logmsg($LogFile,"",true,true)
	_logmsg($LogFile,"List jobs found:",true,true)

	While Not $Recordset.EOF

		Local $MonitorEnabled = 0

		$count += 1

		Local $job_name_original = $Recordset.Fields("job_name").Value
		Local $job_name = StringReplace($job_name_original,",","_")

		Local $is_schedule_enabled = $Recordset.Fields("is_schedule_enabled").Value
		Local $is_job_deleted = $Recordset.Fields("is_job_deleted").Value
		Local $backup_job_type = $Recordset.Fields("job_type").Value

		$CheckJobType = 1

		If $JobTypes <> "" then
			Local $regex = "\b" & $backup_job_type & "\b"
			$CheckJobType = StringRegExp($JobTypes,$regex)
		Endif

		Local $schedule_enabled_ok = 0
		Local $job_deleted_ok = 0
		Local $run_manually = 0

		If $sDriver = "PostgreSQL ANSI" then
			Local $job_options_runmanually = $Recordset.Fields("job_options_runmanually").Value
			$schedule_enabled_ok = _IsTrueValue($is_schedule_enabled)
			$job_deleted_ok = _IsFalseValue($is_job_deleted)
			$run_manually = _IsTrueValue($job_options_runmanually)
		Else
			$schedule_enabled_ok = ($is_schedule_enabled = 1 Or $is_schedule_enabled = "true")
			$job_deleted_ok = ($is_job_deleted = 0 Or $is_job_deleted = "false")
		EndIf

		If ($schedule_enabled_ok And $job_deleted_ok And $CheckJobType > 0 And Not $run_manually) Then
			$MonitorEnabled = 1
		EndIf

		If $MonitorEnabled = 1 Then
			$JobsCount += 1
		EndIf

		If ($job_deleted_ok And $CheckJobType > 0) Then
			$Array_Disc_Tmp &= $Comma & "{" & chr(34) & "{#VEEAMJOB}" & chr(34) & ":" & chr(34) & $job_name & "" & chr(34) & "}"
			$Comma = ","

			$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.enabled[" & $job_name & "]",$MonitorEnabled)
		Endif

		_logmsg($LogFile,"-> (M:" & $MonitorEnabled & ") Job Name: " & $job_name_original,true,true)

		If $Debug > 0 then
			_logmsg($LogFile,"   IsScheduleEnabled: " & $is_schedule_enabled,true,true)
			_logmsg($LogFile,"   IsJobDeleted: " & $is_job_deleted,true,true)
			_logmsg($LogFile,"   CheckJobType (" & $backup_job_type & "): " & $CheckJobType,true,true)
		EndIf

		$Recordset.MoveNext()
	WEnd

	_logmsg($LogFile,"",true,true)

EndFunc

Func BackupData($Recordset,$sDriver)

;~ 	; Old Code
;~ 	Local $aRecordsetArray = _ADO_Recordset_ToArray($Recordset, False)
;~ 	Local $aRecordset_inner = _ADO_RecordsetArray_GetContent($aRecordsetArray)
;~ 	Local $iColumn_count = UBound($aRecordset_inner, $UBOUND_COLUMNS)

;~ 	; Ottieni il numero di righe e colonne
;~ 	Local $iRowCount = UBound($aRecordset_inner, $UBOUND_ROWS)
;~ 	Local $iColumnCount = UBound($aRecordset_inner, $UBOUND_COLUMNS)

;~ 	; Cicla ogni riga
;~ 	For $iRow = 0 To $iRowCount - 1
;~ 		; Cicla ogni colonna nella riga
;~ 		For $iCol = 0 To $iColumnCount - 1
;~ 			; Leggi il valore della cella
;~ 			Local $value = $aRecordset_inner[$iRow][$iCol]
;~ 			ConsoleWrite("Valore alla riga " & $iRow & ", colonna " & $iCol & ": " & $value & @CRLF)
;~ 		Next
;~ 	Next
	;ConsoleWrite(@CRLF & "R: " & UBound($aRecordset_inner) & " C: " & $iColumn_count & @CRLF & @CRLF)

	; job_id
	; job_name
	; repository_id
	; repository_name
	; job_type
	; job_schedule
	; is_job_deleted
	; latest_job_result
	; is_schedule_enabled
	; parent_schedule_id
	; backup_hosts
	; backup_job_type
	; backup_state
	; backup_result
	; backup_creation_time
	; backup_end_time
	; backup_task_status
	; backup_task_reason
	; backup_task_session_id
	; job_schedule_afterjob_enabled
	; job_schedule_daily_enabled
	; job_schedule_daily_kind
	; job_schedule_daily_days
	; job_schedule_monthly_enabled
	; job_schedule_periodically_enabled
	; job_schedule_monthly_months

	While Not $Recordset.EOF

		;Local $MonitorEnabled = 0

		Local $job_name_original = $Recordset.Fields("job_name").Value
		Local $job_name = StringReplace($job_name_original,",","_")

		_logmsg($LogFile,"",true,true)
		_logmsg($LogFile,"-> Original Job Name: " & $job_name_original,true,true)

		Local $backup_creation_time = $Recordset.Fields("backup_creation_time").Value
		Local $backup_creation_time_date = _DateVeeamFormat($backup_creation_time)

		Local $backup_end_time = $Recordset.Fields("backup_end_time").Value
		Local $backup_end_time_date = _DateVeeamFormat($backup_end_time)

		Local $Duration = ""
		If $backup_end_time_date > $backup_creation_time_date then
			$Duration = _DateDiff('n',$backup_creation_time_date,$backup_end_time_date)
		Else
			$Duration = "Backup starting or in progress"
		Endif

		Local $backup_state = $Recordset.Fields("backup_state").Value
		Local $backup_result = $Recordset.Fields("backup_result").Value
		Local $backup_reason = $Recordset.Fields("backup_reason").Value

		Local $backup_task_status = $Recordset.Fields("backup_task_status").Value
		Local $backup_task_reason = $Recordset.Fields("backup_task_reason").Value

		Local $is_schedule_enabled = $Recordset.Fields("is_schedule_enabled").Value
		Local $is_job_deleted = $Recordset.Fields("is_job_deleted").Value

		Local $parent_job_id = $Recordset.Fields("parent_job_id").Value

		Local $backup_job_type = $Recordset.Fields("backup_job_type").Value

;~ 		$CheckJobType = 1

;~ 		If $JobTypes <> "" then
;~ 			Local $regex = "\b" & $backup_job_type & "\b"
;~ 			$CheckJobType = StringRegExp($JobTypes,$regex)
;~ 		Endif

;~ 		If ( $is_schedule_enabled = 1 and $is_job_deleted = 0 and $CheckJobType > 0 ) then
;~ 			$MonitorEnabled = 1
;~ 		Endif

;~ 		If $MonitorEnabled = 1 Then
;~ 			$JobsCount += 1
;~ 		EndIf

		;for $i = 0 to 24
		;	ConsoleWrite(@CRLF & $Recordset.Fields($i).Value)
		;Next

		Local $job_schedule_afterjob_enabled = $Recordset.Fields("job_schedule_afterjob_enabled").Value
		Local $job_schedule_afterjob_name = ""
		Local $job_schedule_daily_enabled = $Recordset.Fields("job_schedule_daily_enabled").Value
		Local $job_schedule_daily_kind = $Recordset.Fields("job_schedule_daily_kind").Value
		Local $job_schedule_daily_days = StringReplace($Recordset.Fields("job_schedule_daily_days").Value," ","")
		Local $job_schedule_daily_days_array = StringSplit($job_schedule_daily_days,",")
		Local $job_schedule_monthly_enabled = $Recordset.Fields("job_schedule_monthly_enabled").Value
		Local $job_schedule_monthly_months = StringReplace($Recordset.Fields("job_schedule_monthly_months").Value," ","")
		Local $job_schedule_monthly_months_array = StringSplit($job_schedule_monthly_months,",")
		Local $job_schedule_periodically_enabled = $Recordset.Fields("job_schedule_periodically_enabled").Value

		Local $parent_schedule_id = $Recordset.Fields("parent_schedule_id").Value

		;ConsoleWrite(@CRLF & "P:" & $parent_job_id & @CRLF)

		If $parent_job_id <> Null then
			$sql = ""
			If $sDriver = "SQL Server" then
				$sql = "SELECT" & @CRLF & _
						"    id," & @CRLF & _
						"    name," & @CRLF & _
						"	 parent_schedule_id," & @CRLF & _
						"    schedule.value('(//OptionsScheduleAfterJob/IsEnabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_afterjob_enabled," & @CRLF & _
						"    schedule.value('(//OptionsDaily/Enabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_daily_enabled," & @CRLF & _
						"    schedule.value('(//OptionsDaily/Kind/text())[1]', 'VARCHAR(MAX)') AS job_schedule_daily_kind," & @CRLF & _
						"    STUFF((" & @CRLF & _
						"        SELECT ', ' + x.EMonth.value('.', 'VARCHAR(MAX)')" & @CRLF & _
						"        FROM schedule.nodes('(//OptionsDaily/Days/DayOfWeek)') AS x(EMonth)" & @CRLF & _
						"        FOR XML PATH('')" & @CRLF & _
						"    ), 1, 2, '') AS job_schedule_daily_days," & @CRLF & _
						"    schedule.value('(//OptionsPeriodically/Enabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_periodically_enabled," & @CRLF & _
						"    schedule.value('(//OptionsMonthly/Enabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_monthly_enabled," & @CRLF & _
						"    STUFF((" & @CRLF & _
						"        SELECT ', ' + x.EMonth.value('.', 'VARCHAR(MAX)')" & @CRLF & _
						"        FROM schedule.nodes('(//OptionsMonthly/Months/EMonth)') AS x(EMonth)" & @CRLF & _
						"        FOR XML PATH('')" & @CRLF & _
						"    ), 1, 2, '') AS job_schedule_monthly_months" & @CRLF & _
						"FROM dbo.[jobsview]" & @CRLF & _
						"WHERE id = '" & $parent_job_id & "';"

			Endif

			If $sDriver = "PostgreSQL ANSI" then
				$sql = "SELECT " & @CRLF & _
					   "    id," & @CRLF & _
					   "    name," & @CRLF & _
					   "	parent_schedule_id," & @CRLF & _
					   "    (xpath('//OptionsScheduleAfterJob/IsEnabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_afterjob_enabled," & @CRLF & _
					   "    (xpath('//OptionsDaily/Enabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_daily_enabled," & @CRLF & _
					   "    (xpath('//OptionsDaily/Kind/text()', xmlparse(document schedule)))[1]::text AS job_schedule_daily_kind," & @CRLF & _
					   "    array_to_string(" & @CRLF & _
					   "        array(" & @CRLF & _
					   "            SELECT unnest(xpath('//OptionsDaily/Days/DayOfWeek/text()', xmlparse(document schedule)))" & @CRLF & _
					   "        ), ', '" & @CRLF & _
					   "    ) AS job_schedule_daily_days," & @CRLF & _
					   "    (xpath('//OptionsMonthly/Enabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_monthly_enabled," & @CRLF & _
					   "    (xpath('//OptionsPeriodically/Enabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_periodically_enabled," & @CRLF & _
					   "    array_to_string(" & @CRLF & _
					   "        array(" & @CRLF & _
					   "            SELECT unnest(xpath('//OptionsMonthly/Months/EMonth/text()', xmlparse(document schedule)))" & @CRLF & _
					   "        ), ', '" & @CRLF & _
					   "    ) AS job_schedule_monthly_months" & @CRLF & _
					   "FROM public.jobsview" & @CRLF & _
					   "WHERE id = '" & $parent_job_id & "';"
			Endif

			;ConsoleWrite(@CRLF & $sql & @CRLF)
			;exit
			$oRecordset_Job = _SqlRetrieveData($sql)

			If IsObj($oRecordset_Job) then
				While Not $oRecordset_Job.EOF

					$parent_schedule_id = $oRecordset_Job.Fields("parent_schedule_id").Value
					$job_schedule_afterjob_enabled = $oRecordset_Job.Fields("job_schedule_afterjob_enabled").Value
					$job_schedule_afterjob_name = $oRecordset_Job.Fields("name").Value
					$job_schedule_daily_enabled = $oRecordset_Job.Fields("job_schedule_daily_enabled").Value
					$job_schedule_daily_kind = $oRecordset_Job.Fields("job_schedule_daily_kind").Value
					$job_schedule_daily_days = StringReplace($oRecordset_Job.Fields("job_schedule_daily_days").Value," ","")
					$job_schedule_daily_days_array = StringSplit($job_schedule_daily_days,",")
					$job_schedule_monthly_enabled = $oRecordset_Job.Fields("job_schedule_monthly_enabled").Value
					$job_schedule_monthly_months = StringReplace($oRecordset_Job.Fields("job_schedule_monthly_months").Value," ","")
					$job_schedule_monthly_months_array = StringSplit($job_schedule_monthly_months,",")
					$job_schedule_periodically_enabled = $oRecordset_Job.Fields("job_schedule_periodically_enabled").Value

					$oRecordset_Job.MoveNext()
				WEnd
			else
				_logmsg($LogFile,"Error Parent Job SQL: " & $oRecordset_Job,true,true)
			Endif
		Endif

		If $job_schedule_afterjob_enabled = "true" and $parent_schedule_id <> Null and $parent_schedule_id <> "00000000-0000-0000-0000-000000000000" then
			$sql = ""
			If $sDriver = "SQL Server" then
				$sql = "WITH ParentHierarchy AS (" & @CRLF & _
						"    -- First level: Retrieve initial record" & @CRLF & _
						"    SELECT" & @CRLF & _
						"        id," & @CRLF & _
						"        parent_schedule_id," & @CRLF & _
						"        name," & @CRLF & _
						"        schedule" & @CRLF & _
						"    FROM" & @CRLF & _
						"        dbo.jobsview" & @CRLF & _
						"    WHERE" & @CRLF & _
						"        id = '" & $parent_schedule_id & "'" & @CRLF & _
						"    UNION ALL" & @CRLF & _
						"    -- Next levels: Search for parent_schedule_id" & @CRLF & _
						"    SELECT" & @CRLF & _
						"        j.id," & @CRLF & _
						"        j.parent_schedule_id," & @CRLF & _
						"        j.name," & @CRLF & _
						"        j.schedule" & @CRLF & _
						"    FROM" & @CRLF & _
						"        dbo.jobsview j" & @CRLF & _
						"    INNER JOIN" & @CRLF & _
						"        ParentHierarchy ph ON j.id = ph.parent_schedule_id" & @CRLF & _
						")" & @CRLF & _
						"-- Select last record found (parent_schedule_id = NULL)" & @CRLF & _
						"SELECT" & @CRLF & _
						"    id," & @CRLF & _
						"    name," & @CRLF & _
						"    schedule.value('(//OptionsScheduleAfterJob/IsEnabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_afterjob_enabled," & @CRLF & _
						"    schedule.value('(//OptionsDaily/Enabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_daily_enabled," & @CRLF & _
						"    schedule.value('(//OptionsDaily/Kind/text())[1]', 'VARCHAR(MAX)') AS job_schedule_daily_kind," & @CRLF & _
						"    STUFF((" & @CRLF & _
						"        SELECT ', ' + x.EMonth.value('.', 'VARCHAR(MAX)')" & @CRLF & _
						"        FROM schedule.nodes('(//OptionsDaily/Days/DayOfWeek)') AS x(EMonth)" & @CRLF & _
						"        FOR XML PATH('')" & @CRLF & _
						"    ), 1, 2, '') AS job_schedule_daily_days," & @CRLF & _
						"    schedule.value('(//OptionsPeriodically/Enabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_periodically_enabled," & @CRLF & _
						"    schedule.value('(//OptionsMonthly/Enabled/text())[1]', 'VARCHAR(MAX)') AS job_schedule_monthly_enabled," & @CRLF & _
						"    STUFF((" & @CRLF & _
						"        SELECT ', ' + x.EMonth.value('.', 'VARCHAR(MAX)')" & @CRLF & _
						"        FROM schedule.nodes('(//OptionsMonthly/Months/EMonth)') AS x(EMonth)" & @CRLF & _
						"        FOR XML PATH('')" & @CRLF & _
						"    ), 1, 2, '') AS job_schedule_monthly_months" & @CRLF & _
						"FROM ParentHierarchy" & @CRLF & _
						"WHERE parent_schedule_id IS NULL;"

			Endif

			If $sDriver = "PostgreSQL ANSI" then
				$sql = "WITH RECURSIVE ParentHierarchy AS (" & @CRLF & _
					   "    -- First level: Retrieve initial record" & @CRLF & _
					   "    SELECT " & @CRLF & _
					   "        id," & @CRLF & _
					   "        parent_schedule_id," & @CRLF & _
					   "        name," & @CRLF & _
					   "        schedule" & @CRLF & _
					   "    FROM " & @CRLF & _
					   "        public.jobsview" & @CRLF & _
					   "    WHERE " & @CRLF & _
					   "        id = '" & $parent_schedule_id & "'" & @CRLF & _
					   "    UNION ALL" & @CRLF & _
					   "    -- Next levels: Search for parent_schedule_id" & @CRLF & _
					   "    SELECT " & @CRLF & _
					   "        j.id," & @CRLF & _
					   "        j.parent_schedule_id," & @CRLF & _
					   "        j.name," & @CRLF & _
					   "        j.schedule" & @CRLF & _
					   "    FROM " & @CRLF & _
					   "        public.jobsview j" & @CRLF & _
					   "    INNER JOIN " & @CRLF & _
					   "        ParentHierarchy ph ON j.id = ph.parent_schedule_id" & @CRLF & _
					   "    WHERE " & @CRLF & _
					   "        ph.parent_schedule_id IS NOT NULL" & @CRLF & _
					   ")" & @CRLF & _
					   "-- Select last record found (parent_schedule_id = NULL)" & @CRLF & _
					   "SELECT " & @CRLF & _
					   "    id," & @CRLF & _
					   "    name," & @CRLF & _
					   "    (xpath('//OptionsScheduleAfterJob/IsEnabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_afterjob_enabled," & @CRLF & _
					   "    (xpath('//OptionsDaily/Enabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_daily_enabled," & @CRLF & _
					   "    (xpath('//OptionsDaily/Kind/text()', xmlparse(document schedule)))[1]::text AS job_schedule_daily_kind," & @CRLF & _
					   "    array_to_string(" & @CRLF & _
					   "        array(" & @CRLF & _
					   "            SELECT unnest(xpath('//OptionsDaily/Days/DayOfWeek/text()', xmlparse(document schedule)))" & @CRLF & _
					   "        ), ', '" & @CRLF & _
					   "    ) AS job_schedule_daily_days," & @CRLF & _
					   "    (xpath('//OptionsMonthly/Enabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_monthly_enabled," & @CRLF & _
					   "    (xpath('//OptionsPeriodically/Enabled/text()', xmlparse(document schedule)))[1]::text AS job_schedule_periodically_enabled," & @CRLF & _
					   "    array_to_string(" & @CRLF & _
					   "        array(" & @CRLF & _
					   "            SELECT unnest(xpath('//OptionsMonthly/Months/EMonth/text()', xmlparse(document schedule)))" & @CRLF & _
					   "        ), ', '" & @CRLF & _
					   "    ) AS job_schedule_monthly_months" & @CRLF & _
					   "FROM ParentHierarchy" & @CRLF & _
					   "WHERE parent_schedule_id IS NULL;"
			Endif

			$oRecordset_Schedule = _SqlRetrieveData($sql)
			If IsObj($oRecordset_Schedule) then
				While Not $oRecordset_Schedule.EOF
					$job_schedule_afterjob_name = $oRecordset_Schedule.Fields("name").Value
					$job_schedule_daily_enabled = $oRecordset_Schedule.Fields("job_schedule_daily_enabled").Value
					$job_schedule_daily_kind = $oRecordset_Schedule.Fields("job_schedule_daily_kind").Value
					$job_schedule_daily_days = StringReplace($oRecordset_Schedule.Fields("job_schedule_daily_days").Value," ","")
					$job_schedule_daily_days_array = StringSplit($job_schedule_daily_days,",")
					$job_schedule_monthly_enabled = $oRecordset_Schedule.Fields("job_schedule_monthly_enabled").Value
					$job_schedule_monthly_months = StringReplace($oRecordset_Schedule.Fields("job_schedule_monthly_months").Value," ","")
					$job_schedule_monthly_months_array = StringSplit($job_schedule_monthly_months,",")
					$job_schedule_periodically_enabled = $oRecordset_Schedule.Fields("job_schedule_periodically_enabled").Value

					$oRecordset_Schedule.MoveNext()
				WEnd
			else
				_logmsg($LogFile,"Error Parent Schedule SQL: " & $oRecordset_Schedule,true,true)
			Endif
		Endif

		$nextBackupDate = ""

		If $job_schedule_daily_enabled = "true" then
			If $job_schedule_daily_kind = "Everyday" then
				$nextBackupDate = _DateAdd("D",1,$backup_creation_time_date)
			Else
				$nextBackupDate = CalculateNextBackupDate($backup_creation_time_date,"D",$job_schedule_daily_days_array)
			EndIf
		EndIf

		If $job_schedule_periodically_enabled = "true" then
			$nextBackupDate = _DateAdd("D",1,$backup_creation_time_date)
		EndIf

		If $job_schedule_monthly_enabled = "true" then
			Local $nextBackupDate = CalculateNextBackupDate($backup_creation_time_date,"M",$job_schedule_monthly_months_array)
		EndIf

		; Old code that add 1+ day at the nextschedule
		;$checkBackupDateLate = _Dateadd("D",1,$nextBackupDate)

		;ConsoleWrite(@CRLF & $backup_creation_time_date & " - " & $nextBackupDate & @CRLF)
		$DateDiff_Check = _DateDiff('D',$backup_creation_time_date,$nextBackupDate)

		$DateDiff = _DateDiff('D',$backup_creation_time_date,_NowCalc())
		$DateDiff = $DateDiff - $DateDiff_Check

		;$Array_Disc_Tmp &= $Comma & "{" & chr(34) & "{#VEEAMJOB}" & chr(34) & ":" & chr(34) & $job_name & "" & chr(34) & "}"
		;$Comma = ","

		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.job.state[" & $job_name & "]",$backup_state)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.job.result[" & $job_name & "]",$backup_result)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.job.reason[" & $job_name & "]",$backup_reason)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.status[" & $job_name & "]",$backup_task_status)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.reason[" & $job_name & "]",$backup_task_reason)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.creationtime[" & $job_name & "]",$backup_creation_time_date)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.endtime[" & $job_name & "]",$backup_end_time_date)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.datediff[" & $job_name & "]",$DateDiff)
		$Zabbix_Items = _add_item_zabbix($Zabbix_Items,"backup.veeam.customchecks.duration[" & $job_name & "]",$Duration)

		; Debug
		if $Debug = 1 then
			_logmsg($LogFile,"JobName: " & $job_name_original,true,true)
			_logmsg($LogFile,"JobNameMonitoring: " & $job_name,true,true)
			;_logmsg($LogFile,"MonitoringEnabled: " & $MonitorEnabled,true,true)
			_logmsg($LogFile,"JobType: " & $backup_job_type,true,true)
			_logmsg($LogFile,"SessionState: " & $backup_state,true,true)
			_logmsg($LogFile,"SessionResult: " & $backup_result,true,true)
			_logmsg($LogFile,"SessionReason: " & $backup_reason,true,true)
			_logmsg($LogFile,"Status: " & $backup_task_status,true,true)
			_logmsg($LogFile,"Reason: " & $backup_task_reason,true,true)
			_logmsg($LogFile,"CreationTime: " & $backup_creation_time_date & " (" & $backup_creation_time & ")",true,true)
			_logmsg($LogFile,"EndTime: " & $backup_end_time_date & " (" & $backup_end_time & ")",true,true)
			_logmsg($LogFile,"Duration (Min): " & $Duration,true,true)
			_logmsg($LogFile,"DateDiff: " & $DateDiff,true,true)
			_logmsg($LogFile,"ScheduleEnabled: " & $is_schedule_enabled,true,true)
			_logmsg($LogFile,"NextSchedule: " & $nextBackupDate,true,true)
			_logmsg($LogFile,"DateDiffCheck: " & $DateDiff_Check,true,true)
			_logmsg($LogFile,"AfterJobEnabled: " & $job_schedule_afterjob_enabled,true,true)
			_logmsg($LogFile,"AfterJobName: " & $job_schedule_afterjob_name,true,true)
			_logmsg($LogFile,"DailyEnabled: " & $job_schedule_daily_enabled,true,true)
			_logmsg($LogFile,"MonthlyEnabled: " & $job_schedule_monthly_enabled,true,true)
			_logmsg($LogFile,"PeriodicallyEnabled: " & $job_schedule_periodically_enabled,true,true)
			_logmsg($LogFile,"ParentScheduleID: " & $parent_schedule_id,true,true)
			_logmsg($LogFile,"JobDeleted: " & $is_job_deleted,true,true)
		endif

		$Recordset.MoveNext()
	WEnd

	_logmsg($LogFile,"",true,true)

EndFunc

Func GetDaysInMonth($year, $month)
    Local $days = Int(@MON[$month])
    If $month = 2 And Mod($year, 4) = 0 And (Mod($year, 100) <> 0 Or Mod($year, 400) = 0) Then
        $days = 29
    EndIf
    Return $days
EndFunc

Func IsValidDate($year, $month, $day)
    Return $day <= GetDaysInMonth($year, $month)
EndFunc

; Convert Veeam data to usable format
Func _DateVeeamFormat($date_string)
    $date = -1

	$date_string = StringStripWS($date_string,$STR_STRIPSPACES)

    ; Format AM/PM
    If StringInStr($date_string, "AM") Or StringInStr($date_string, "PM") Then
		local $parts = StringSplit($date_string, " ")

		local $month_str = $parts[1]
		local $day = $parts[2]
		local $year = $parts[3]
		local $time_str = $parts[4]

		local $months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
		local $month = 0
		For $i = 0 To 11
			If $months[$i] = $month_str Then
				$month = $i + 1
				ExitLoop
			EndIf
		Next

		local $time_parts = StringSplit($time_str, ":")
		local $hour = $time_parts[1]
		local $min = $time_parts[2]
		local $ampm = StringRight($time_str, 2)

		$hour = Int($hour)

		If $ampm == "PM" Then
			If $hour <> 12 Then
				$hour = $hour + 12
			EndIf
		ElseIf $ampm == "AM" Then
			If $hour == 12 Then
				$hour = 0
			EndIf
		EndIf

		$date = $year & "/" & StringFormat("%02d", $month) & "/" & StringFormat("%02d", $day) & " " & StringFormat("%02d", $hour) & ":" & StringFormat("%02d", $min) & ":00"

    ElseIf StringLen($date_string) = 14 Then
		; parsig format 20241125100000
        local $year = StringLeft($date_string,4)
		local $month = StringMid($date_string,5,2)
		local $day = StringMid($date_string,7,2)
		local $hour = StringMid($date_string,9,2)
		local $min = StringMid($date_string,11,2)
		local $sec = StringMid($date_string,13,2)
		$date = $year & "/" & $month & "/" & $day & " " & $hour & ":" & $min & ":" & $sec
    EndIf

    Return $date
EndFunc
Func MapMonthToNumber($monthName)
    Local $monthsNames[12] = ["January", "February", "March", "April", "May", "June", _
                               "July", "August", "September", "October", "November", "December"]
    For $i = 0 To UBound($monthsNames) - 1
        If $monthsNames[$i] = $monthName Then
            Return $i + 1
        EndIf
    Next
    Return -1
EndFunc

Func MapDayToNumber($dayName)
    Local $daysNames[12] = ["Sunday" , "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    For $i = 0 To UBound($daysNames) - 1
        If $daysNames[$i] = $dayName Then
            Return $i + 1
        EndIf
    Next
    Return -1
EndFunc

Func ParseMonthsFromXML($xml)
    Local $oXML = ObjCreate("Microsoft.XMLDOM")
    Local $monthsList = []
    If $oXML.loadXML($xml) Then
        Local $nodes = $oXML.SelectNodes("//ScheduleOptions/OptionsMonthly/Months/EMonth")
        For $node In $nodes
            _ArrayAdd($monthsList, $node.text)
        Next
	Else
		ConsoleWrite(@CRLF & "Errore: " & $oXML.parseError.reason & @CRLF & @CRLF & $xml & @CRLF & @CRLF)
    EndIf
    Return $monthsList
EndFunc

Func CalculateNextBackupDate($lastBackupDate, $type, $list)

	Local $nextBackupDate = $lastBackupDate
	Local $MaxTries = 1

	If $type ="M" then
		$MaxTries = 12
	EndIf
	If $type ="D" then
		$MaxTries = 7
	EndIf

    Local $temporalNames[1] = [0]
    For $i = 1 To $list[0]
		If $type ="M" then
			Local $Num = MapMonthToNumber($list[$i])
		EndIf
		If $type ="D" then
			Local $Num = MapDayToNumber($list[$i])
		EndIf

        If $Num > 0 Then
            _ArrayAdd($temporalNames, $Num)
        EndIf
    Next

	$temporalNames[0] = UBound($temporalNames) - 1

    _ArraySort($temporalNames,0,1)

    if UBound($temporalNames) = 0 then
		return $nextBackupDate
	endif

	$count = 0

    Local $found = False
    While Not $found
		$count += 1
		if $count > $MaxTries then
			$found = True

			Local $nextBackupDate = $lastBackupDate
			$nextBackupDate = _DateAdd($type, 1, $nextBackupDate)
			Local $datearray = StringSplit($nextBackupDate,"/")
			Local $nextName
			If $type = "M" then
				$nextName = Number($datearray[2])
			EndIf
			If $type = "D" then
				$nextName = _DateToDayOfWeek($datearray[1],$datearray[2],$datearray[3])
			EndIf

			_logmsg($LogFile,"Search " & $type & " failed. Exit with first result",true,true)
			_logmsg($LogFile,"BackupDate: " & $lastBackupDate & " NextBackupDate: " & $nextBackupDate & " (Tries: " & $count & ")",true,true)
			ExitLoop
		endif

        $nextBackupDate = _DateAdd($type, 1, $nextBackupDate)

		Local $datearray = StringSplit($nextBackupDate,"/")
        Local $nextName
		If $type = "M" then
			$nextName = Number($datearray[2])
		EndIf
		If $type = "D" then
			$nextName = _DateToDayOfWeek($datearray[1],$datearray[2],$datearray[3])
		EndIf

        For $i = 1 To $temporalNames[0]
            If $temporalNames[$i] = $nextName Then
                $found = True
                ExitLoop
            EndIf
        Next

    WEnd

    Return $nextBackupDate
EndFunc

; Extract data from xml
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
