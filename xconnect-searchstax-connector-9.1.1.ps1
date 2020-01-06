Import-Module powershell-yaml

$configPath=".\config.yml"
$solrConfigPath721 = "xconnect_solr-config-7.2.1.zip"
$start_time = Get-Date
$collections = @("_xdb","_xdb_rebuild" )
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
    $global:xdbSolrConfigName=$yaml.settings.xdbSolrConfigName
    $global:pathToWWWRoot=$yaml.settings.pathToWWWRoot
    $global:solrUsername=$yaml.settings.solrUsername
    $global:solrPassword=$yaml.settings.solrPassword
    $global:sitecoreVersion=$yaml.settings.sitecoreVersion
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

function Upload-Config($solrVersion, $token, $solrConfigName) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")

        if ($solrVersion -eq "7.2.1") {
            $form = @{
                name = $solrConfigName
                files = Get-Item -Path $solrConfigPath721
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
function Create-Collections($solrVersion, $token, $solrConfigName) {
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
    foreach($collection in $collections){
        $collection | Write-Host
        if ($solrVersion -eq "7.2.1") {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$sitecorePrefix,$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$solrConfigName)
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

if ($sitecoreVersion -eq "9.1.1") {
    $solrVersion = "7.2.1"
} else {
    Write-Error -Message "Unsupported sitecore version specified. Supported versions are 9.1.1" -ErrorAction Stop
}


Write-Host "Sitecore Version - $sitecoreVersion"
Write-Host "Solr Version - $solrVersion"
Write-Host
$token = Get-Token
Check-DeploymentExist($token)
Upload-Config $solrVersion $token $xdbSolrConfigName
Get-Node-Count $token
Create-Collections $solrVersion $token $xdbSolrConfigName
Write-Output "Time taken: $((Get-Date).Subtract($start_time))"
Write-Host "FINISHED"