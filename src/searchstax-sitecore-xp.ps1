function Upload-Configs($solrVersion, $token) {
    "Uploading Configs:"

    if ($isUniqueConfigs) {
        foreach($collection in $coll){
            $configName = -join('',$sitecorePrefix,$collection)
            Write-Host "Uploading $configName config..."
            Upload-Config $configName $solrVersion $token
        }
    } else {

        $configName = "sitecore_$sitecorePrefix"
        Write-Host "Uploading $configName config..."
        Upload-Config $configName $solrVersion $token
    }
}

function Upload-CustomConfigs($solrVersion, $token) {
    "Uploading Custom Configs:"

    foreach($customIndex in $global:customIndexes){
        $configName = -join('',$sitecorePrefix,$customIndex.core)
        Write-Host "Uploading $configName config..."
        Upload-Config $configName $solrVersion $token
    }
}

function Upload-Config($configName, $solrVersion, $token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")

        $configList = Invoke-RestMethod -Method Get -Headers $headers -uri $configUploadUrl

        $solrConfigPath = -join($xpConfigPath,$solrVersion,'.zip')

        if($configList.configs -contains $configName) {
            Write-Host "$configName exists already. Skipping."
            return;
        }

        $form = @{
            name = $configName
            files = Get-Item -Path $solrConfigPath
        }
        Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl
    } catch {
        Write-Warning -Message "Unable to upload config file. Error was: $_" -ErrorAction Stop
    }
}

function Create-Collections($solr, $nodeCount) {
    "Creating Collections:"

    foreach($collection in $coll){
        if($global:switchOnRebuildCollections.Contains($collection)) {
            $collectionName = -join($switchOnRebuildSitecorePrefix,$collection)
        } else {
            $collectionName = -join($sitecorePrefix,$collection)
        }
        if ($isUniqueConfigs) {
            $configName = -join($sitecorePrefix,$collection)
        } else {
            $configName = -join("sitecore_",$sitecorePrefix)
        }

        Write-Host "Creating $collectionName collection..."
        Create-Collection $collectionName $configName $solr $nodeCount
    }
}

function Create-CustomCollections($solr, $nodeCount) {
    "Creating Custom Collections: "

    foreach($customIndex in $global:customIndexes){
        Write-Host "Creating Custom $customIndex collection..."
        $customIndexName = $customIndex.core
        $configName = -join('',$sitecorePrefix,$customIndex.core)
        Create-Collection $customIndexName $configName $solr $nodeCount

        if($customIndex.isSwitchOnRebuild -eq "true") {
            $customIndexRebuildCollection = -join($customIndexName,$switchOnRebuildSufix)
            Write-Host "Creating SwitchOnRebuild $customIndexRebuildCollection collection..."
            Create-Collection $customIndexRebuildCollection $configName $solr $nodeCount

            $rebuildCollectionAlias = -join($customIndexName,$switchOnRebuildAlias)
            Write-Host "Creating $rebuildCollectionAlias alias for $customIndexRebuildCollection collection"
            Create-SwitchOnRebuildAlias $rebuildCollectionAlias $customIndexRebuildCollection $solr

            $mainCollectionAlias = -join($customIndexName,$switchOnRebuildMainAlias)
            Write-Host "Creating $mainCollectionAlias alias for $customIndexName collection"
            Create-SwitchOnRebuildAlias $mainCollectionAlias $customIndexName $solr
        }
    }
}

function Create-SwitchOnRebuildCollections($solr, $nodeCount) {
    "Creating SwitchOnRebuild Collections: "

    foreach($collection in $global:switchOnRebuildCollections){
        $collectionName = -join($switchOnRebuildSitecorePrefix,$collection,$switchOnRebuildSufix)
        if ($isUniqueConfigs) {
            $configName = -join($sitecorePrefix,$collection)
        } else {
            $configName = -join("sitecore_",$sitecorePrefix)
        }
        Write-Host "Creating SwitchOnRebuild $collectionName collection..."
        Create-Collection $collectionName $configName $solr $nodeCount
    }
}

function Create-Collection($collectionName, $configName, $solr, $nodeCount) {
    try {
        if ($solrUsername.length -gt 0){
            $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
        }
        $url = -join($solr, "admin/collections?action=CREATE&name=",$collectionName,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$configName)
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

function Create-SwitchOnRebuildAliases($solr) {
    "Creating SwitchOnRebuild Aliases:"

    foreach($collection in $global:switchOnRebuildCollections){
        $rebuildCollectionName = -join($switchOnRebuildSitecorePrefix,$collection,$switchOnRebuildSufix)
        $rebuildCollectionAlias = -join($switchOnRebuildSitecorePrefix,$collection,$switchOnRebuildAlias)

        Write-Host "Creating $rebuildCollectionAlias alias for $rebuildCollectionName collection"
        Create-SwitchOnRebuildAlias $rebuildCollectionAlias $rebuildCollectionName $solr

        $mainCollectionName = -join($switchOnRebuildSitecorePrefix,$collection)
        $mainCollectionAlias = -join($switchOnRebuildSitecorePrefix,$collection,$switchOnRebuildMainAlias)

        Write-Host "Creating $mainCollectionAlias alias for $mainCollectionName collection"
        Create-SwitchOnRebuildAlias $mainCollectionAlias $mainCollectionName $solr
    }
}

function Create-SwitchOnRebuildAlias($aliasName, $collectioName, $solr) {
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }

    $url = -join($solr, "admin/collections?action=CREATEALIAS&name=",$aliasName,"&collections=",$collectioName)
    if ($solrUsername.length -gt 0){
        Invoke-WebRequest -Uri $url -Credential $credential
    }
    else {
        Invoke-WebRequest -Uri $url
    }
}