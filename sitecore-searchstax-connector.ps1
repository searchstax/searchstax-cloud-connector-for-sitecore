Import-Module powershell-yaml

$configPath=".\config.yml"
$xpConfigPath=".\Configs\xp\solr_config-"
$xConnectConfigPath=".\Configs\xconnect\xconnect-config-"
$commerceConfigPath=".\Configs\commerce\v"
$start_time = Get-Date
$collections = @("_master_index","_core_index","_web_index","_marketingdefinitions_master","_marketingdefinitions_web","_marketing_asset_index_master","_marketing_asset_index_web","_testing_index","_suggested_test_index","_fxm_master_index","_fxm_web_index" )
$collections93 = @("_master_index","_core_index","_web_index","_marketingdefinitions_master","_marketingdefinitions_web","_marketing_asset_index_master","_marketing_asset_index_web","_testing_index","_suggested_test_index","_fxm_master_index","_fxm_web_index","_personalization_index" )
$collectionsXConnect = @("xdb_internal", "xdb_rebuild_internal")
$searchstaxUrl = 'https://app.searchstax.com'
$authUrl = -join($searchstaxUrl, '/api/rest/v1/obtain-auth-token/')
# DEFAULT VALUES AS SUGGESTED BY SITECORE
#Max return rows from solr
$searchMaxResults="500"
#Max items in a batch
$batchSize="500"
# DEFAULT VALUES AS SUGGESTED BY SITECORE - END

function Init {
    [string[]]$fileContent = Get-Content $configPath
    $content = ''
    foreach ($line in $fileContent) { 
        $content = $content + "`n" + $line 
    }
    $yaml = ConvertFrom-YAML $content

    # Get base values
    $global:accountName=$yaml.settings.accountName
    $global:deploymentUid=$yaml.settings.deploymentUid
    $global:sitecorePrefix=$yaml.settings.sitecorePrefix
    $global:pathToWWWRoot=$yaml.settings.pathToWWWRoot
    $global:solrUsername=$yaml.settings.solrUsername
    $global:solrPassword=$yaml.settings.solrPassword
    $global:sitecoreVersion=$yaml.settings.sitecoreVersion
    $global:isUniqueConfigs=Get-BooleanValue $yaml.settings.isUniqueConfigs

    # Get configuration mode
    $global:configurationMode=$yaml.settings.configurationMode
    $configurationModeArray=$configurationMode.split("|")
    $global:isConfigureXP=$false
    $global:isConfigureXConnect=$false
    foreach($instMode in $configurationModeArray){
        if($instMode.ToUpper() -eq "XP"){
            $global:isConfigureXP=$true
        } Elseif ($instMode.ToUpper() -eq "XCONNECT") {
            $global:isConfigureXConnect=$true
        } Elseif ($instMode.ToUpper() -eq "COMMERCE") {
            $global:isConfigureCommerce=$true
        } else {
            Write-Error -Message "Invalid Configuration mode" -ErrorAction Stop
        }
    }
    if (-Not $isConfigureXP -And -Not $isConfigureXConnect -And -Not $isConfigureCommerce){
        Write-Error -Message "Please select at least 1 Configuration mode" -ErrorAction Stop
    }

    # Get Values for Commerce if Configuration mode is Commerce
    if ($isConfigureCommerce) {
        $global:commerceServicesPostfix = $yaml.settings.commerce.commerceServicesPostfix
        $global:isXCSwitchOnRebuild = Get-BooleanValue $yaml.settings.commerce.isXCSwitchOnRebuild
    }



    # Configure internal variables
    $global:deploymentReadUrl = -join($searchstaxUrl,'/api/rest/v2/account/',$accountName,'/deployment/',$deploymentUid,'/')
    $global:configUploadUrl = -join($searchstaxUrl,'/api/rest/v2/account/',$accountName,'/deployment/',$deploymentUid,'/zookeeper-config/')

    $global:xConnectCollectionAlias = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $global:xConnectCollectionAlias.Add("xdb_internal", "xdb")
    $global:xConnectCollectionAlias.Add("xdb_rebuild_internal", "xdb_rebuild")
}

function Get-BooleanValue($val){
    if ($val -eq "true") {
        return $true
    } Elseif ($val -eq "false") {
        return $false
    } else {
        Write-Error -Message "Invalid value provided for boolean. [true/false]" -ErrorAction Stop
    }
}

function Get-Token {
    # "Please provide authentication information."
    $uname = Read-Host -Prompt 'Username - '
    $password = Read-Host -AsSecureString -Prompt 'Password - '
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
    
    Write-Host "Asking for an authorization token for $uname..."
    Write-Host

    $body = @{
        username=$uname
        password=$password
    }
    Remove-Variable PASSWORD

    $body = $body | ConvertTo-Json
    try {
        $token = Invoke-RestMethod -uri "https://app.searchstax.com/api/rest/v2/obtain-auth-token/" -Method Post -Body $body -ContentType 'application/json' 
        $token = $token.token
        Remove-Variable body

        Write-Host "Obtained token" $token
        Write-Host
        
        return $token
    } catch {
         Write-Error -Message "Unable to get Auth Token. Error was: $_" -ErrorAction Stop
    }
}

function Check-DeploymentExist($token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")
        $result = Invoke-WebRequest -Method Get -Headers $headers -uri $deploymentReadUrl
        if ($result.statuscode -eq 200) {
            Write-Host "Deployment found. Continuing."
        } else {
            Write-Error "Could not find deployment. Exiting." -ErrorAction Stop
        }
    } catch {
        Write-Error -Message "Unable to verify if deployment exists. Error was: $_" -ErrorAction Stop
    }
}

function Get-Node-Count($token) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Token $token")
    $result = Invoke-RestMethod -Method Get -ContentType 'application/json' -Headers $headers -uri $deploymentReadUrl
    return [int]$result.num_nodes_default + [int]$result.num_additional_app_nodes
}

function Get-SolrUrl($token) {
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Token $token")
    $result = Invoke-RestMethod -Method Get -ContentType 'application/json' -Headers $headers -uri $deploymentReadUrl
    return $result.http_endpoint
}

function Update-XML($path, $xpath, $attributeKey, $attributeValue){
    if (Test-Path -LiteralPath $path) {
        $xml = New-Object XML
        $xml.Load($path)
        $node =  $xml.SelectSingleNode($xpath)
        $node.SetAttribute($attributeKey,$attributeValue)
        $xml.Save($path)
    }
    else {
         Write-Error -Message "Could not find $path File"
    }
}

if (!($PSVersionTable.PSVersion.Major -ge 6)){
    Write-Host "This script is only compatible with Powershell Core v6 and above."
    Write-Host
    Write-Host "You can install Powershell Core v6 using following command - "
    Write-Host "iex `"& { `$(irm https://aka.ms/install-powershell.ps1) } -UseMSI`""
    Write-Host
    Write-Host "Please restart this script using Powershell Core v6"
    Write-Error -Message "" -ErrorAction Stop
}

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { Start-Process pwsh.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }

# Initializing Script

Init
. "src\searchstax-sitecore-xp.ps1"
. "src\searchstax-sitecore-xconnect.ps1"
. "src\searchstax-sitecore-commerce.ps1"

# Initializing Script Ends

if ($sitecoreVersion -eq "9.0.2") {
    $solrVersion = "6"
    $global:isUniqueConfigs= $true
    $global:coll = $collections
} Elseif ($sitecoreVersion -eq "9.1.1") {
    $solrVersion = "7.2.1"
    $global:coll = $collections
} Elseif ($sitecoreVersion -eq "9.2.0") {
    $solrVersion = "7.5.0"
    $global:coll = $collections
}
Elseif ($sitecoreVersion -eq "9.3.0") {
    $solrVersion = "8.1.1"
    $global:coll = $collections93
}
 else {
    Write-Error -Message "Unsupported sitecore version specified. Supported versions are 9.0.2, 9.1.1, 9.2.0, and 9.3.0" -ErrorAction Stop
}


Write-Host "Sitecore Version    - $sitecoreVersion"
Write-Host "Solr Version        - $solrVersion"
Write-Host "Configuration Mode   - $configurationMode"
Write-Host
$token = Get-Token
Check-DeploymentExist($token)
"Getting live node count ..."
$nodeCount = Get-Node-Count $token
"Getting live node count ... DONE"
"Number of nodes - $nodeCount"
$solr = Get-SolrUrl $token

if ($isConfigureXP){
    Upload-Config $solrVersion $token
    Create-Collections $solr $nodeCount
    Update-SitecoreConfigs $sitecoreVersion $solr
}

if ($isConfigureXConnect){
    Upload-XConnect-Config $solrVersion $token
    Create-XConnect-Collections $solr $nodeCount
    Create-XConnect-Alias $solr $nodeCount
    Update-XConnect-SitecoreConfigs $solr
    Update-XConnect-Schema $solr
}

if ($isConfigureCommerce){
    Write-Host "Installing Commerce"
    Get-Dictionary-For-Collections
    Upload-Commerce-Config $solrVersion $token
    Create-Commerce-Collections $solr $nodeCount
    Update-Commerce-Configs $solr
}


"Restarting IIS"
"NOTE: If you have UAC enabled, then this step might fail with 'Access Denied' error."
"Please either disable UAC, or restart IIS manually if the error occurs."
& {iisreset}
Write-Output "Time taken: $((Get-Date).Subtract($start_time))"
Write-Host "FINISHED"
