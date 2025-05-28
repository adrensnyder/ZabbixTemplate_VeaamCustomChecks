# VeeamCustomChecks_ZabbixTemplate

I'm not satisfied about the [official template of Veeam](https://www.zabbix.com/integrations/veeam) for Zabbix because the API it's incomplete not give all the information i need to monitor correctly the backups
Because of those I've created mine that connects directly to MS SQL or POSTGRES.

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
This project isn't affiliated with Veeam. It will not modify Veeam software in any manner nor the license that are needed to work.
This template and executable only retrieve detailed informations from the internal database and send it to zabbix.
Hope to see more informations in the API in the future so i can create an API only template

