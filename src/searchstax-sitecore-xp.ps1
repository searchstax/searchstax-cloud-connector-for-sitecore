function Upload-Config($solrVersion, $token) {
    try {
        "Uploading Configs... "

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")

        $configList = Invoke-RestMethod -Method Get -Headers $headers -uri $configUploadUrl

        $solrConfigPath = -join($xpConfigPath,$solrVersion,'.zip')

        if ($isUniqueConfigs) {
            foreach($collection in $coll){
                $confName = -join('',$sitecorePrefix,$collection)
                Write-Host $confName
                if($configList.configs -contains $confName) {
                    Write-Host "$confName exists already. Skipping."
                    continue
                }
                $form = @{
                    name = $confName
                    files = Get-Item -Path $solrConfigPath
                }
                Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
            }
        } else {
            $form = @{
                name = "sitecore_$sitecorePrefix"
                files = Get-Item -Path $solrConfigPath
            }
            if($configList.configs -contains "sitecore_$sitecorePrefix") {
                Write-Host "sitecore_$sitecorePrefix exists already. Skipping."
                continue
            }
            Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
        }

    } catch {
        Write-Warning -Message "Unable to upload config file. Error was: $_" -ErrorAction Stop
    }
}

function Create-Collections($solr, $nodeCount) {
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating Collections... "

    foreach($collection in $coll){
        try {
            if($isSwitchOnRebuild -and $switchOnRebuildCollections.Contains($collection)) {
                $collectionName = -join($switchOnRebuildPrefix,$collection)
            } else {
                $collectionName = -join($sitecorePrefix,$collection)
            }

            $collectionName  | Write-Host
            -join($solr, "admin/collections?action=CREATE&name=",$collectionName,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$sitecorePrefix,$collection) | Write-Host
            if ($isUniqueConfigs) {
                $url = -join($solr, "admin/collections?action=CREATE&name=",$collectionName,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$sitecorePrefix,$collection)
            } else {
                $url = -join($solr, "admin/collections?action=CREATE&name=",$collectionName,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=sitecore_$sitecorePrefix")
            }

            if ($solrUsername.length -gt 0){
                Invoke-WebRequest -Uri $url -Credential $credential
            }
            else {
                Invoke-WebRequest -Uri $url
            }
        } catch {
            Write-Warning -Message "Unable to create collection $collectionName. Error was: $_" -ErrorAction Stop
        }
    }
}

function Create-SwitchOnRebuildCollections($solr, $nodeCount) {
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating SwitchOnRebuild Collections... "

    foreach($collection in $switchOnRebuildCollections){
        try {
            $collectionName = -join($switchOnRebuildPrefix,$collection,$switchOnRebuildSufix)
            $collectionName  | Write-Host
            if ($isUniqueConfigs) {
                $url = -join($solr, "admin/collections?action=CREATE&name=",$collectionName,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$sitecorePrefix,$collection)
            } else {
                $url = -join($solr, "admin/collections?action=CREATE&name=",$collectionName,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=sitecore_$sitecorePrefix")
            }

            if ($solrUsername.length -gt 0){
                Invoke-WebRequest -Uri $url -Credential $credential
            }
            else {
                Invoke-WebRequest -Uri $url
            }
        } catch {
            Write-Warning -Message "Unable to create switchOnRebuild collection $collectionName. Error was: $_" -ErrorAction Stop
        }
    }
}

function Create-SwitchOnRebuildAliases($solr) {
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating SwitchOnRebuild Aliases ... "

    foreach($collection in $switchOnRebuildCollections){
        $rebuildCollectionName = -join($switchOnRebuildPrefix,$collection,$switchOnRebuildSufix)
        $rebuildCollectionName  | Write-Host
        $rebuildCollectionAlias = -join($switchOnRebuildPrefix,$collection,$switchOnRebuildAlias)
        $rebuildCollectionAlias  | Write-Host

        $url = -join($solr, "admin/collections?action=CREATEALIAS&name=",$rebuildCollectionAlias,"&collections=",$rebuildCollectionName)
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
        }

        $mainCollectionName = -join($switchOnRebuildPrefix,$collection)
        $mainCollectionName  | Write-Host
        $mainCollectionAlias = -join($switchOnRebuildPrefix,$collection,$switchOnRebuildMainAlias)
        $mainCollectionAlias  | Write-Host

        $url = -join($solr, "admin/collections?action=CREATEALIAS&name=",$mainCollectionAlias,"&collections=",$mainCollectionName)
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
        }
    }
}