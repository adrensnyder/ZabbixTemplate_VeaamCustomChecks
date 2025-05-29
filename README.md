# VeeamCustomChecks_ZabbixTemplate

I'm not satisfied with the [official template of Veeam Backup and Replication](https://www.zabbix.com/integrations/veeam) for Zabbix, as the API does not provide all the information needed to properly monitor backups in a efficiently way.
For this reason, I created my own template, which connects directly to MS SQL or PostgreSQL.

## Database Versions
- **v11** uses mostly SQL Server.
- **v12** uses PostgreSQL and requires psqlodbc to be installed in both 32-bit and 64-bit versions from [here](https://www.postgresql.org/ftp/odbc/releases/).
  - Default port: 5432
  - Default user: `postgres` (without password)

## Status Codes
- **Status 0:** Backup succeeded

## Item Names and Targets
- **R:** Uses the `RepositoryId` tag in the `work_details` field (Image clone)
- **D:** Uses the `hostDnsName` tag in the `work_details` field (Usually Replica jobs)
- **A:** Tries to get information for the backup with an agent installed

## Configurable MACROS
The template includes several configurable MACROS with descriptions of their usage.

## Paths and Configuration
- Change the path of the executable in the item `[VEEAM] Collect Data` if needed.
- The variable `$ZabbixBasePath` is hardcoded to the path `c:\zabbix_agent`.
  - It will create a configuration file on the first execution with the configurable path of `zabbix_sender.exe` and Zabbix configuration.

## Items
| Name | Key |
| --- | --- |
| [VEEAM-CST] [{#VEEAMJOB}] Job Task - Status	| backup.veeam.customchecks.status[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Task - Reason	| backup.veeam.customchecks.reason[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Session - State	| backup.veeam.customchecks.job.state[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Session - Result	| backup.veeam.customchecks.job.result[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Session - Reason	| backup.veeam.customchecks.job.reason[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Session - End Time	| backup.veeam.customchecks.duration[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Session - Duration	| backup.veeam.customchecks.creationtime[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job Session - Creation Time	| backup.veeam.customchecks.status[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job - Monitoring Enabled	| backup.veeam.customchecks.enabled[{#VEEAMJOB}] |
| [VEEAM-CST] [{#VEEAMJOB}] Job - Difference days from now	| backup.veeam.customchecks.datediff[{#VEEAMJOB}] |

The differences from the official template are that this version allows you to directly monitor the latest backup status, identify any jobs that ended with errors or warnings, and detect any backups that are delayed for any reason.
The original template does not monitor all types (IDs) of backup jobs and only retrieves the various sessions. If a session for a job returns an error but the next one is successful, the alert remains in Zabbix for a while, resulting in a false positive.

# ToDo
- Add detection of Disabled jobs
- Add detection if a job have the Automatic Schedule enabled
- Add monitor of Internal database backup 
 
# Copyright
This project is an unofficial Zabbix template for monitoring Veeam backup jobs. It is not affiliated with, endorsed, or supported by Veeam Software in any way.  
“Veeam” and related trademarks are the property of Veeam Software.  

This template and the included executable do not modify Veeam software in any way, nor do they interfere with its licensing.  
All data is retrieved in read-only mode from the internal database and sent to Zabbix for monitoring purposes.  

The goal is to provide more detailed monitoring until Veeam expands its public API capabilities, at which point an API-only solution may be developed.  

