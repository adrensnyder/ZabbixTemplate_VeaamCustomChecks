# VeeamCustomChecks_ZabbixTemplate

I'm not satisfied about the official template of Veeam for Zabbix, so I've created mine that connects directly to MS SQL or POSTGRES.

## Database Versions
- **v11** uses SQL Server.
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
