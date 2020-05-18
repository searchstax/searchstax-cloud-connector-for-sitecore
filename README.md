# SearchStax Sitecore Plugin
## Introduction
This script is used to connect a Sitcore installation to a SearchStax' Solr instance. 
It does following: 
- Upload the config files to Solr
- Create collections in Solr
- Configure sitecore files

## Supported Sitecore Versions
Currently the script only supports following sitecore XP versions and their XConnect:
- 9.0 Update-2 (9.0.2)
- 9.1 Update-1 (9.1.1) 
- 9.2 Initial Update (9.2.0)
- 9.3 Initial Update (9.3.0)

Sitecore Commerce:
- 9.2 Initial Update (9.2.0)
- 9.3 Initial Update (9.3.0)

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
|isUniqueConfigs| "true" will create a separate config file for each collection, "false" will create only 1 config which will be used by all the collections. (Note: This defaults to true for Sitecore v9.0.2) | true/false|
|configurationMode| Select the part of Sitecore being configured - "XP", "XCONNECT", "COMMERCE" | XP\|XCONNECT|
|CommerceServicesPostfix| Suffix used for Sitecore Commerce installation. This is defined in Sitecore XC installation script.|"Sc9"|
|isXCSwitchOnRebuild| Whether Sitecore commerce has been configured to use Switch On Rebuild feature. (v9.3.0 and above)| true/false|

### Instructions
1. Configure the `config.yml` file.
2. Start Powershell Core v6 as Administrator.
3. Change the execution policy to skip checking.
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
4. Execute following command
```powershell
.\sitecore-searchstax-connector.ps1
```
5. Go to your sitecore page > Control Panel > Populate Solr Managed Schema > Select All > Populate
6. On the same page, Indexing Manager > Select All > Rebuild

## How can I get help with SearchStax Sitecore Plugin?

You can use GitHub to submit [bug reports](https://github.com/searchstax/searchstax-sitecore-plugin/issues/new?template=bug_report.md) or [feature requests](https://github.com/searchstax/searchstax-sitecore-plugin/issues/new?template=feature_request.md) for SearchStax-Sitecore-Plugin. Please do not submit usage questions via GitHub.

## FAQ
### SolrCloud
This script by default sets "solrCloud=true" in all the connection strings because all the deployments at SearchStax work in a SolrCloud mode.
#### Limitations of setting solrCloud=true
There is a known bug in Sitecore where if solrCloud=true is added to Sitecore XP then Sitecore tries to connect to private IP of Solr cluster when opening the "Index Manager" dialog box. 
Here is an excerpt from Sitecore regarding this bug:
>The described error is related to the inability to connect to the private IP address which causes the timeout. As I can understand this is an internal Solr cluster node IP address that is in a private network. It looks like Sitecore tries to access each replica which is on a private network for security reasons and as expected, this causes a time out and result "Unable to connect to the remote server" exception. The error only appears when using "Index Manager", because it tries to get "Index statistics" from the inner SOLR nodes. Please note that we have registered this behavior as a bug in our tracking system.
>To track the future status of this bug report, please use the reference number 355209.
>More information about public reference numbers can be found here: https://kb.sitecore.net/articles/853187>>
>
>As a workaround of the issue, please consider rebuilding indexes via Content Editor. I am looking forward to hearing from you

### Sitecore Commerce
Currently Sitecore Commerce configuration is supported for only v9.2 - Initial Update and v9.3 - Initial Update.
### Sitecore SXA
This plugin currently does not support Sitecore SXA configuration.
### IP Filtering
If you have enabled IP filtering on your Solr instance, then make sure that you add the IP/CIDR block of your network or machine to the IP Filtering page. For more instructions on how to set up IP filtering, please follow our guide here - [How To Set-up IP Filtering](https://www.searchstax.com/docs/security/#IPfilter)
### Sitecore v9.0 Update-2
The plugin will automatically default to creating a separate config directory for every collection when being used to setup Sitecore v9.0.2.
