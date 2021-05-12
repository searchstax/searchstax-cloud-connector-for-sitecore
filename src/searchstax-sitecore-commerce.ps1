function Get-Name-Commerce-Directories {
    $allDirectories = Get-ChildItem -Path $pathToWWWRoot -Directory -Force -ErrorAction SilentlyContinue | Select-Object FullName
    $directories = @()
    foreach($item in $allDirectories){
        if($item.FullName.contains($commerceServicesPostfix)) {
            $directories += $item.FullName
        }
    }

    return $directories
}

function Get-Dictionary-For-Collections {
    $commerceDirectories = Get-Name-Commerce-Directories
    if($commerceDirectories.Count -lt 1) {
        Write-Error -Message "Could not find any directories matching the provided PostScript" -ErrorAction Stop
    }
    $global:commercePrimaryDict = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $global:commerceConfigDict = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    if ($isXCSwitchOnRebuild){
        $global:commerceSecondaryDict = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    }
    if ($sitecoreVersion -eq "9.3.0"){
        $path = -join($commerceDirectories[0],"\wwwroot\data\Environments\PlugIn.Search.PolicySet-1.0.0.json")
        $dataOfPolicyJson = Get-Content -Raw -Path $path | ConvertFrom-Json
        foreach($item in $dataOfPolicyJson.Policies.'$values'){
            if($item.'$type' -like 'Sitecore.Commerce.Plugin.Search.SearchScopePolicy, Sitecore.Commerce.Plugin.Search')  {
                if($item.Name -like "Catalog*") {
                    $global:commercePrimaryDict.Add("Catalog",$item.CurrentIndexName)
                    $global:commerceConfigDict.Add("Catalog","CECatalogItemsIndexConfig")
                    if ($isXCSwitchOnRebuild) {
                        $global:commerceSecondaryDict.Add("Catalog",$item.SwitchOnRebuildSecondaryIndexName)
                    }
                }
                if($item.Name -like "Order*") {
                    $global:commercePrimaryDict.Add("Order",$item.CurrentIndexName)
                    $global:commerceConfigDict.Add("Order","CEOrdersIndexConfig")
                    if ($isXCSwitchOnRebuild) {
                        $global:commerceSecondaryDict.Add("Order",$item.SwitchOnRebuildSecondaryIndexName)
                    }
                }
                if($item.Name -like "Customer*") {
                    $global:commercePrimaryDict.Add("Customer",$item.CurrentIndexName)
                    $global:commerceConfigDict.Add("Customer","CECustomersIndexConfig")
                    if ($isXCSwitchOnRebuild) {
                        $global:commerceSecondaryDict.Add("Customer",$item.SwitchOnRebuildSecondaryIndexName)
                    }
                }
                if($item.Name -like "Price*") {
                    $global:commercePrimaryDict.Add("Price",$item.CurrentIndexName)
                    $global:commerceConfigDict.Add("Price","CEPriceCardsIndexConfig")
                    if ($isXCSwitchOnRebuild) {
                        $global:commerceSecondaryDict.Add("Price",$item.SwitchOnRebuildSecondaryIndexName)
                    }
                }
                if($item.Name -like "Promotion*") {
                    $global:commercePrimaryDict.Add("Promotion",$item.CurrentIndexName)
                    $global:commerceConfigDict.Add("Promotion","CEPromotionsIndexConfig")
                    if ($isXCSwitchOnRebuild) {
                        $global:commerceSecondaryDict.Add("Promotion",$item.SwitchOnRebuildSecondaryIndexName)
                    }
                }
            }
        }
    }
    if ($sitecoreVersion -eq "9.2.0"){
        $path = -join($commerceDirectories[0],"\wwwroot\data\Environments\PlugIn.Search.PolicySet-1.0.0.json")
        $dataOfPolicyJson = Get-Content -Raw -Path $path | ConvertFrom-Json
        foreach($item in $dataOfPolicyJson.Policies.'$values'){
            if($item.'$type' -like 'Sitecore.Commerce.Plugin.Search.SearchScopePolicy, Sitecore.Commerce.Plugin.Search')  {
                if($item.Name -like "Catalog*") {
                    $global:commercePrimaryDict.Add("Catalog",$item.Name)
                    $global:commerceConfigDict.Add("Catalog","CECatalogItemsIndexConfig")
                }
                if($item.Name -like "Order*") {
                    $global:commercePrimaryDict.Add("Order",$item.Name)
                    $global:commerceConfigDict.Add("Order","CEOrdersIndexConfig")
                }
                if($item.Name -like "Customer*") {
                    $global:commercePrimaryDict.Add("Customer",$item.Name)
                    $global:commerceConfigDict.Add("Customer","CECustomersIndexConfig")
                }
            }
        }
    }
    # $global:commercePrimaryDict
    # $global:commerceSecondaryDict
}

function Upload-Commerce-Config($solrVersion, $token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")
        
        foreach ($key in $commerceConfigDict.Keys) {
            Write-Host "Uploading config named" $commerceConfigDict[$key] "for" $commercePrimaryDict[$key]
            $confPath = -join($commerceConfigPath,$sitecoreVersion,'\',$commerceConfigDict[$key],'.zip')
            Write-Host $confPath
            $form = @{
                name = $commerceConfigDict[$key]
                files = Get-Item -Path $confPath
            }
            Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
        }

    } catch {
        Write-Error -Message "Unable to upload XDB config file. Error was: $_" -ErrorAction Stop
    }  
}

function Create-Commerce-Collections($solr, $nodeCount) {
    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating Commerce Collections ... "

    foreach ($key in $commerceConfigDict.Keys) {
        Write-Host $key
        $url = -join($solr, "admin/collections?action=CREATE&name=",$commercePrimaryDict[$key],"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$commerceConfigDict[$key])
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
            # Write-Host $url
        }

        if ($isXCSwitchOnRebuild) {
           $url = -join($solr, "admin/collections?action=CREATE&name=",$commerceSecondaryDict[$key],"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$commerceConfigDict[$key])
            if ($solrUsername.length -gt 0){
                Invoke-WebRequest -Uri $url -Credential $credential
            }
            else {
                Invoke-WebRequest -Uri $url
                # Write-Host $url
            }
        }
    }
}

function Update-Commerce-Configs ($solr) {
    $commerceDirectories = Get-Name-Commerce-Directories
    $solr = $solr.substring(0,$solr.length-1)
    
    if($commerceDirectories.Count -lt 1) {
        Write-Error -Message "Could not find any directories matching the provided PostScript" -ErrorAction Stop
    }
    if ($sitecoreVersion -eq "9.3.0"){
        if ($solrUsername.length -gt 0) {
            $solr = -join("https://",$solrUsername,":",$solrPassword,"@",$solr.substring(8,$solr.length-8))
        }
        foreach($directory in $commerceDirectories){
            $path = -join($directory,"\wwwroot\data\Environments\PlugIn.Search.Solr.PolicySet-1.0.0.json")
            Write-Host "Updating config -" $path
            $dataOfPolicyJson = Get-Content -Raw -Path $path | ConvertFrom-Json
            foreach($item in $dataOfPolicyJson.Policies.'$values'){
                if($item.'$type' -like 'Sitecore.Commerce.Plugin.Search.Solr.SolrSearchPolicy, Sitecore.Commerce.Plugin.Search.Solr')  {
                    $item.SolrUrl = $solr
                    $item.IsSolrCloud = $True
                }
            }
            $dataOfPolicyJson | ConvertTo-Json -depth 100 | Out-File $path
        }        
    }
    if ($sitecoreVersion -eq "9.2.0"){
        foreach($directory in $commerceDirectories){
            $path = -join($directory,"\wwwroot\data\Environments\PlugIn.Search.Solr.PolicySet-1.0.0.json")
            Write-Host "Updating config -" $path
            $dataOfPolicyJson = Get-Content -Raw -Path $path | ConvertFrom-Json
            foreach($item in $dataOfPolicyJson.Policies.'$values'){
                if($item.'$type' -like 'Sitecore.Commerce.Plugin.Search.Solr.SolrSearchPolicy, Sitecore.Commerce.Plugin.Search.Solr')  {
                    $item.SolrUrl = $solr
                    $item.IsSolrCloud = $True
                    if ($solrUsername.length -gt 0) {
                        $item.SolrUserName = $solrUsername
                        $item.SolrPassword = $solrPassword
                    }
                }
            }
            $dataOfPolicyJson | ConvertTo-Json -depth 100 | Out-File $path
        }        
    }    
}