# searchstax-sitecore-plugin
## Introduction
This script is used to connect a sitcore XP0 installation to a SearchStax' Solr instance. 
It does following: 
- Upload the config files to Solr
- Create collections in Solr
- Configure sitecore files

## Supported Sitecore Versions
Currently the script only supports following sitecore versions:
- 9.0 Update-2 
- 9.1 Update-1  

## Requirements
- Powershell Core v6 or above
- Powershell-yaml  module

### Installing
#### Powershell Core v6
Powershell Core v6 can be installed by running following command via Powershell Windows.
```powershell
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"
```

#### Powershell Yaml Module
```powershell
Install-Module powershell-yaml
```

## Running the script
In order to run the script, first you have to update the config file
### Config File
Config file is located at `.\config.yml`  

It contains following fields:

|Name|Description|Example|
|----|:-----------|:-----|
|accountName|Name of the SearchStax account| ABCInternational |
|deploymentUid| UID of the SearchStax deployment to connect to| ss123456 |
|sitecorePrefix| Prefix of the sitecore installation| sitecore |
|pathToWWWRoot| Path to wwwroot folder in inetpub, i.e. your %IIS_SITE_HOME% variable| C:\inetpub\wwwroot|
|solrUsername| Solr username (Optional)||
|solrPassword| Solr password (Optional)||
|sitecoreVersion| Version of sitecore from the above list| 9.1.1|

### Instructions
1. Configure the `config.yml` file.
2. Start Powershell Core v6 as Administrator.
3. Execute following command
```powershell
.\sitecore-searchstax-connector.ps1
```
