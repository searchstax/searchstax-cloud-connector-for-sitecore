function Upload-SXA-Config($solrVersion, $token) {
    "Uploading SXA Configs:"

    foreach($collection in $sxaColl){
        Write-Host "Uploading $collection config..."
        Upload-Config $collection $solrVersion $token
    }
}

function Create-SXA-Collections($solr, $nodeCount) {
    "Creating SXA Collections:"

    foreach($collection in $sxaColl){
        Write-Host "Creating $collection collection for SXA..."
        Create-Collection $collection $collection $solr $nodeCount

        if($global:switchOnRebuildEnableForSXA) {
            $sxaIndexRebuildCollection = -join($collection,$switchOnRebuildSufix)
            Write-Host "Creating SwitchOnRebuild $sxaIndexRebuildCollection collection for SXA..."
            Create-Collection $sxaIndexRebuildCollection $collection $solr $nodeCount

            $rebuildCollectionAlias = -join($collection,$switchOnRebuildAlias)
            Write-Host "Creating $rebuildCollectionAlias alias for $sxaIndexRebuildCollection collection for SXA"
            Create-SwitchOnRebuildAlias $rebuildCollectionAlias $sxaIndexRebuildCollection $solr

            $mainCollectionAlias = -join($collection,$switchOnRebuildMainAlias)
            Write-Host "Creating $mainCollectionAlias alias for $collection collection for SXA"
            Create-SwitchOnRebuildAlias $mainCollectionAlias $collection $solr
        }
    }
}

