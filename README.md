# VeeamCustomChecks_ZabbixTemplate

I'm not satisfied about the official template of Veeam for Zabbix because the API it's incomplete not give all the information i need to monitor correctly the backups
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
 
# Copyright
This project isn't affiliated with Veeam. It will not modify Veeam software in any manner nor the license that are needed to work.
This template and executable only retrieve detailed informations from the internal database and send it to zabbix.

