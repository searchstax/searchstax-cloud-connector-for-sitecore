Import-Module powershell-yaml

$configPath=".\config.yml"
$solrConfigPath6 = ".\Configs\solr_config-6.zip"
$solrConfigPath721 = ".\Configs\solr_config-7.2.1.zip"
$solrConfigPath750 = ".\Configs\solr_config-7.5.0.zip"
$solrConfigPath811 = ".\Configs\solr_config-8.1.1.zip"
$start_time = Get-Date
$collections = @("_master_index","_core_index","_web_index","_marketingdefinitions_master","_marketingdefinitions_web","_marketing_asset_index_master","_marketing_asset_index_web","_testing_index","_suggested_test_index","_fxm_master_index","_fxm_web_index" )
$collections93 = @("_master_index","_core_index","_web_index","_marketingdefinitions_master","_marketingdefinitions_web","_marketing_asset_index_master","_marketing_asset_index_web","_testing_index","_suggested_test_index","_fxm_master_index","_fxm_web_index","_personalization_index" )
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
    $global:accountName=$yaml.settings.accountName
    $global:deploymentUid=$yaml.settings.deploymentUid
    $global:sitecorePrefix=$yaml.settings.sitecorePrefix
    $global:pathToWWWRoot=$yaml.settings.pathToWWWRoot
    $global:solrUsername=$yaml.settings.solrUsername
    $global:solrPassword=$yaml.settings.solrPassword
    $global:sitecoreVersion=$yaml.settings.sitecoreVersion
    if ($yaml.settings.isUniqueConfigs -eq "true") {
        $global:isUniqueConfigs= $true
    } Elseif ($yaml.settings.isUniqueConfigs -eq "false") {
        $global:isUniqueConfigs= $false
    } else {
        Write-Error -Message "Invalid value provided for isUniqueConfigs. [true/false]" -ErrorAction Stop
    }

    $global:deploymentReadUrl = -join($searchstaxUrl,'/api/rest/v2/account/',$accountName,'/deployment/',$deploymentUid,'/')
    $global:configUploadUrl = -join($searchstaxUrl,'/api/rest/v2/account/',$accountName,'/deployment/',$deploymentUid,'/zookeeper-config/')
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

function Upload-Config($solrVersion, $token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")
        if ($solrVersion -eq "7.2.1") {
            $solrConfigPath= $solrConfigPath721
        } Elseif ($solrVersion -eq "7.5.0") {
            $solrConfigPath= $solrConfigPath750
        }
         Elseif ($solrVersion -eq "8.1.1") {
            $solrConfigPath= $solrConfigPath811
        }
         Elseif ($solrVersion -eq "6") {
            $solrConfigPath=  $solrConfigPath6
        }

        if ($isUniqueConfigs) {
            foreach($collection in $coll){
                $confName = -join('',$sitecorePrefix,$collection)
                Write-Host $confName
                $form = @{
                    name = $confName
                    files = Get-Item -Path $solrConfigPath
                }
                # Write-Host $body
                Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
            }
        } else {
            $form = @{
                name = "sitecore_$sitecorePrefix"
                files = Get-Item -Path $solrConfigPath
            }
            Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
        }

    } catch {
        Write-Error -Message "Unable to upload config file. Error was: $_" -ErrorAction Stop
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

#TODO : Too many moving parts - Add try-catch blocks and make it fault tolerant
function Create-Collections($token) {
    "Getting live node count ..."
    $nodeCount = Get-Node-Count $token
    "Getting live node count ... DONE"
    "Number of nodes - $nodeCount"
    $solr = Get-SolrUrl $token
    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating Collections ... "

    foreach($collection in $coll){
        $collection | Write-Host
        if ($isUniqueConfigs) {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$sitecorePrefix,$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$sitecorePrefix,$collection)
        } else {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$sitecorePrefix,$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=sitecore_$sitecorePrefix")
        }

        
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
            # Write-Host $url
        }
        
    }
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

function Update-WebConfig {
    "Updating Web.Config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\Web.config")
    $xpath = "//configuration/appSettings/add[@key='search:define']"
    $attributeKey = "value"
    $attributeValue = "Solr"
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-ConnectionStringsConfig ($token) {
    "Updating ConnectionStrings.Config file"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\ConnectionStrings.config")
    $xpath = "//connectionStrings/add[@name='solr.search']"
    $solr = Get-SolrUrl $token
    $solr = $solr.substring(0,$solr.length-1)
    if ($solrUsername.length -gt 0) {
        $solr = -join("https://",$solrUsername,":",$solrPassword,"@",$solr.substring(8,$solr.length-8))
    }

    $attributeKey = "connectionString"
    $attributeValue = $solr
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-EnableSearchProvider {
    "Updating Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\Sitecore\ContentSearch\Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config")
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.Provider']"
    $attributeKey = "value"
    $attributeValue = "Solr"
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-MaxNumberOfSearchResults {
    "Updating Sitecore.ContentSearch.config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\Sitecore\ContentSearch\Sitecore.ContentSearch.config")
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.SearchMaxResults']"
    $attributeKey = "value"
    $attributeValue = $searchMaxResults
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-EnableBatchMode {
    "Updating Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\Sitecore\ContentSearch\Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config")
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.Update.BatchModeEnabled']"
    $attributeKey = "value"
    $attributeValue = "true"
    Update-XML $path $xpath $attributeKey $attributeValue
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.Update.BatchSize']"
    $attributeKey = "value"
    $attributeValue = $batchSize
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-SitecoreConfigs ($sitecoreVersion, $token) {
    if ($sitecoreVersion -eq "9.0.2") {
        Update-WebConfig
        Update-ConnectionStringsConfig $token
        Update-EnableSearchProvider
        Update-MaxNumberOfSearchResults
        Update-EnableBatchMode
    } Elseif ($sitecoreVersion -eq "9.1.1") {
        Update-WebConfig
        Update-ConnectionStringsConfig $token
    } Elseif ($sitecoreVersion -eq "9.2.0") {
        Update-WebConfig
        Update-ConnectionStringsConfig $token
    }
	Elseif ($sitecoreVersion -eq "9.3.0") {
        Update-WebConfig
        Update-ConnectionStringsConfig $token
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

Init



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


Write-Host "Sitecore Version - $sitecoreVersion"
Write-Host "Solr Version - $solrVersion"
Write-Host
$token = Get-Token
Check-DeploymentExist($token)
Upload-Config $solrVersion $token
Get-Node-Count $token
Create-Collections $token
Update-SitecoreConfigs $sitecoreVersion $token
"Restarting IIS"
"NOTE: If you have UAC enabled, then this step might fail with 'Access Denied' error."
"Please either disable UAC, or restart IIS manually if the error occurs."
& {iisreset}
Write-Output "Time taken: $((Get-Date).Subtract($start_time))"
Write-Host "FINISHED"