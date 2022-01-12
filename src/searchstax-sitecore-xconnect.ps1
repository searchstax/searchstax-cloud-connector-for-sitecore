function Upload-XConnect-Config($solrVersion, $token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")


        $solrConfigPath = -join($xConnectConfigPath,$solrVersion,'.zip')
        $confName = -join('',$sitecorePrefix,'_xdb')
        Write-Host $confName
        $form = @{
            name = $confName
            files = Get-Item -Path $solrConfigPath
        }
        Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 

    } catch {
        Write-Error -Message "Unable to upload XDB config file. Error was: $_" -ErrorAction Stop
    }    
}

function Create-XConnect-Collections($solr, $nodeCount) {
    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating XDB Collections ... "

    foreach($collection in $collectionsXConnect){
        $collection | Write-Host
        $url = -join($solr, "admin/collections?action=CREATE&name=",$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$sitecorePrefix,"_xdb")
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
            # Write-Host $url
        }
        
    }
}

function Create-XConnect-Alias($solr, $nodeCount) {
    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating XDB Aliases ... "

    foreach($collection in $collectionsXConnect){
        $collection | Write-Host
        $url = -join($solr, "admin/collections?action=CREATEALIAS&name=",$sitecorePrefix,"_",$xConnectCollectionAlias[$collection],"&collections=",$collection)
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
            # Write-Host $url
        }
        
    }
}

function Update-XConnectConnectionStringsConfig ($solr, $path) {
    "Updating XConnect ConnectionStrings in '$path' file"    
    $xpath = "//connectionStrings/add[@name='solrCore']"
    $solr = $solr.substring(0,$solr.length-1)
    if ($solrUsername.length -gt 0) {
        $solr = -join("https://",$solrUsername,":",$solrPassword,"@",$solr.substring(8,$solr.length-8))
    }
    $attributeKey = "connectionString"
    $attributeValue = -join($solr,"/xdb;solrcloud=true")
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-XConnect-SitecoreConfigs ($solr) {
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".xconnect\App_Config\ConnectionStrings.config")
    Update-XConnectConnectionStringsConfig $solr $path
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".xconnect\App_Data\jobs\continuous\IndexWorker\App_Config\ConnectionStrings.config")
    Update-XConnectConnectionStringsConfig $solr $path
}

function Update-XConnect-Schema ($solr) {
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".xconnect\App_Data\solrcommands\schema.json")
    $json = Get-Content -Raw -Path $path

    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Updating XDB Schema ... "

    foreach($collection in $collectionsXConnect){
        $collection | Write-Host
        $url = -join($solr, $collection,"/schema")
        if ($solrUsername.length -gt 0){
            Invoke-RestMethod -Uri $url -Credential $credential -ContentType 'application/json' -Method POST -Body $json
        }
        else {
            Invoke-RestMethod -Uri $url -ContentType 'application/json' -Method POST -Body $json
            # Write-Host $url
            # Write-Host $json
        }
        
    }
}