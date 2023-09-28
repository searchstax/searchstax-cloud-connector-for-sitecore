function Create-SXA-Collections($solr, $nodeCount) {
    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating SXA Collections ... "

    foreach($collection in $sxaColl){
        $collection | Write-Host
        if ($isUniqueConfigs) {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$collection)
        } else {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=sitecore_",$sitecorePrefix)
        }

        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
        }
    }
}

function Upload-SXA-Config($solrVersion, $token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")

        $configList = Invoke-RestMethod -Method Get -Headers $headers -uri $configUploadUrl

        $solrConfigPath = -join($xpConfigPath,$solrVersion,'.zip')

        if ($isUniqueConfigs) {
            foreach($collection in $sxaColl){
                $confName = $collection
                Write-Host $confName
                if($configList.configs -contains $confName) {
                    Write-Host "$confName exists already. Skipping."
                    continue
                }
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
            if($configList.configs -contains "sitecore_$sitecorePrefix") {
                Write-Host "sitecore_$sitecorePrefix exists already. Skipping."
                continue
            }
            Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
        }

    } catch {
        Write-Error -Message "Unable to upload config file. Error was: $_" -ErrorAction Stop
    }    
}

