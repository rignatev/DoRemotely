function Invoke-ObjectFilters {
    [CmdletBinding()]
    param (
        # The object to filter
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [psobject[]]
        $InputObject,

        # An object with filters imported from json settings using the Import-ObjectFilterSettings function
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowNull()]
        [psobject[]]
        $Filters,

        # Enables filter section Include 
        [Parameter(Mandatory = $false, Position = 2)]
        [switch]
        $Enable
    )
    
    process {
        if ($Enable) {
            if (-not $Filters) {
                throw 'No filters found'
            }
            foreach ($item in $InputObject) {
                $skipObject = $false
                foreach ($filter in $Filters) {
                    if (-not $filter.Enabled) {
                        continue
                    }
                    $includeMatched = $false
                    $excludeMatched = $false
                    foreach ($actionsProperty in $filter.Actions.PSObject.Properties) {
                        switch ($actionsProperty.Name) {
                            'Include' {
                                $action = 'Include'
                                break
                            }
                            'Exclude' {
                                $action = 'Exclude'
                                break
                            }
                            Default {
                                $action = $null
                            }
                        }

                        if ($action) {
                            foreach ($actionValues in $actionsProperty.Value.PSObject.Properties) {
                                $itemPropertyNames = @(($item | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name))
                                if ($itemPropertyNames -contains $actionValues.Name) {
                                    foreach ($actionValue in $actionValues.Value) {
                                        if ($filter.Settings.CaseSensitive) {
                                            if ($filter.Settings.Equality) {
                                                $hasMatched = $item.$($actionValues.Name) -ceq $actionValue
                                            }
                                            else {
                                                if ($filter.Settings.Regex) {
                                                    $hasMatched = $item.$($actionValues.Name) -cmatch $actionValue
                                                }
                                                else {
                                                    $hasMatched = $item.$($actionValues.Name) -clike $actionValue
                                                }
                                            }
                                        }
                                        else {
                                            if ($filter.Settings.Equality) {
                                                $hasMatched = $item.$($actionValues.Name) -eq $actionValue
                                            }
                                            else {
                                                if ($filter.Settings.Regex) {
                                                    $hasMatched = $item.$($actionValues.Name) -match $actionValue
                                                }
                                                else {
                                                    $hasMatched = $item.$($actionValues.Name) -like $actionValue
                                                }
                                            }                                    
                                        }
                                        
                                        if ($hasMatched) {
                                            if ($action -eq 'Include') {
                                                $includeMatched = $true
                                            }
                                            if ($action -eq 'Exclude') {
                                                $excludeMatched = $true
                                            }                                    
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if ($filter.Settings.IncludeEnabled -and $filter.Settings.ExcludeEnabled) {
                        if ($includeMatched -and $excludeMatched) {
                            if ($filter.Settings.IncludeFirst) {
                                $skipObject = $false
                            }
                            else {
                                $skipObject = $true
                            }                            
                        }
                        if ($includeMatched -and -not $excludeMatched) {
                            $skipObject = $false
                        }
                        if (-not $includeMatched -and $excludeMatched) {
                            $skipObject = $true
                        }
                        if (-not $excludeMatched -and -not $includeMatched) {
                            $skipObject = $true
                        }
                    }
                    elseif ($filter.Settings.IncludeEnabled) {
                        if ($includeMatched) {
                            $skipObject = $false
                        }
                        else {
                            $skipObject = $true
                        }
                    }
                    elseif ($filter.Settings.ExcludeEnabled) {
                        if ($excludeMatched) {
                            $skipObject = $true
                        }
                        else {
                            $skipObject = $false
                        }                    
                    }

                    if ($skipObject) {
                        return
                    }
                }

                $item
            }
        }
        else {
            $InputObject
        }
    }
}