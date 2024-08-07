# VeaamCustomChecks_ZabbixTemplate
I'm not satisfied about the official template of Veeam for zabbix so i've created mine that connects directly to MS SQL or POSTGRES

The v11 use SQL Server.
The v12 use PostgreSQL and require to have installed psqlodbc in both 32bit/64bit versions from here https://www.postgresql.org/ftp/odbc/releases/
The default port of PostgreSQL is 5432
The default user is "postgres" without password

Status 0: Backup succeded

The names of the items contains the Target of the backup.
R: Use the RepositoryId tag in the work_details field (Image clone)
D: Use the hostDnsName tag in the work_details field (Usually Replica jobs)
A: Try to get informations for the backup with an agent installed

The template have some configurable MACROS with a description of the usage

Change the path of the executable in the item "[VEEAM] Collect Data" if needed

The variable "$ZabbixBasePath" is hardcoded with the path c:\zabbix_agent.
It will create a configuration file on the first execution with the configurable path of zabbix_sender.exe and zabbix configuration
