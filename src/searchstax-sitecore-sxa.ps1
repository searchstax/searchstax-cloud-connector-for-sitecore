function Upload-SXA-Config($solrVersion, $token) {
    "Uploading SXA Configs:"

    foreach($collection in $sxaColl){
        $collectionName = -join($sitecorePrefix,$collection)
        Write-Host "Uploading $collectionName config..."
        Upload-Config $collectionName $solrVersion $token
    }
}

function Create-SXA-Collections($solr, $nodeCount) {
    "Creating SXA Collections:"

    foreach($collection in $sxaColl){
        $collectionName = -join($sitecorePrefix,$collection)
        Write-Host "Creating $collectionName collection for SXA..."
        Create-Collection $collectionName $collectionName $solr $nodeCount

        if($global:switchOnRebuildEnableForSXA) {
            $sxaIndexRebuildCollection = -join($collectionName,$switchOnRebuildSufix)
            Write-Host "Creating SwitchOnRebuild $sxaIndexRebuildCollection collection for SXA..."
            Create-Collection $sxaIndexRebuildCollection $collectionName $solr $nodeCount

            $rebuildCollectionAlias = -join($collectionName,$switchOnRebuildAlias)
            Write-Host "Creating $rebuildCollectionAlias alias for $sxaIndexRebuildCollection collection for SXA"
            Create-SwitchOnRebuildAlias $rebuildCollectionAlias $sxaIndexRebuildCollection $solr

            $mainCollectionAlias = -join($collectionName,$switchOnRebuildMainAlias)
            Write-Host "Creating $mainCollectionAlias alias for $collectionName collection for SXA"
            Create-SwitchOnRebuildAlias $mainCollectionAlias $collectionName $solr
        }
    }
}
