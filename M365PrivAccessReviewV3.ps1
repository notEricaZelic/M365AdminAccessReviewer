# Initialize arrays
$directoryRoleMembers = @()
$pimActive = @()
$pimEligible = @()

# Capture timestamp at script start
$timestampNow = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Get all directoryRole members
$roles = Get-MgDirectoryRole
foreach ($role in $roles) {
    Write-Host "Processing DirectoryRole: $($role.DisplayName)"
    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All
    foreach ($member in $members) {
        $directoryRoleMembers += [PSCustomObject]@{
            PrincipalId = $member.Id
            RoleName = $role.DisplayName
            Source = "DirectoryRole"
        }
    }
}

# Get all active PIM assignments
$pimActiveInstances = Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All
foreach ($active in $pimActiveInstances) {
    $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $active.RoleDefinitionId
    $pimActive += [PSCustomObject]@{
        PrincipalId = $active.PrincipalId
        RoleName = $roleDef.DisplayName
        Source = "PIM Active"
    }
}

# Get all eligible PIM assignments
$pimEligibleInstances = Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -All
foreach ($eligible in $pimEligibleInstances) {
    $roleDef = Get-MgRoleManagementDirectoryRoleDefinition -UnifiedRoleDefinitionId $eligible.RoleDefinitionId
    $pimEligible += [PSCustomObject]@{
        PrincipalId = $eligible.PrincipalId
        RoleName = $roleDef.DisplayName
        Source = "PIM Eligible"
    }
}

# Build master list of unique (PrincipalId + RoleName) combos
$allAssignments = @()

$allKeys = ($directoryRoleMembers + $pimActive + $pimEligible) |
    ForEach-Object { "$($_.PrincipalId)|$($_.RoleName)" } |
    Select-Object -Unique

foreach ($key in $allKeys) {
    $split = $key -split "\|"
    $principalId = $split[0]
    $roleName = $split[1]

    # Determine assignment types
    $assignmentTypes = @()
    if ($directoryRoleMembers | Where-Object { $_.PrincipalId -eq $principalId -and $_.RoleName -eq $roleName }) {
        $assignmentTypes += "DirectoryRole"
    }
    if ($pimActive | Where-Object { $_.PrincipalId -eq $principalId -and $_.RoleName -eq $roleName }) {
        $assignmentTypes += "PIM Active"
    }
    if ($pimEligible | Where-Object { $_.PrincipalId -eq $principalId -and $_.RoleName -eq $roleName }) {
        $assignmentTypes += "PIM Eligible"
    }

    # Resolve object type
    $displayName = ""
    $userPrincipalName = ""
    $objectType = "Unknown"
    $groupMembers = ""

    $user = Get-MgUser -UserId $principalId -ErrorAction SilentlyContinue
    if ($user) {
        $displayName = $user.DisplayName
        $userPrincipalName = $user.UserPrincipalName
        $objectType = "User"
    } else {
        $sp = Get-MgServicePrincipal -ServicePrincipalId $principalId -ErrorAction SilentlyContinue
        if ($sp) {
            $displayName = $sp.DisplayName
            $userPrincipalName = $sp.AppId
            if ($sp.Tags -contains "ManagedIdentity") {
                $objectType = "ManagedIdentity"
            } else {
                $objectType = "ServicePrincipal"
            }
        } else {
            $group = Get-MgGroup -GroupId $principalId -ErrorAction SilentlyContinue
            if ($group) {
                $displayName = $group.DisplayName
                $objectType = "Group"
                # Resolve group members
                $members = Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue
                if ($members) {
                    $memberNames = @()
                    foreach ($m in $members) {
                        if ($m.AdditionalProperties.displayName) {
                            $memberNames += $m.AdditionalProperties.displayName
                        } elseif ($m.AdditionalProperties.userPrincipalName) {
                            $memberNames += $m.AdditionalProperties.userPrincipalName
                        } elseif ($m.AdditionalProperties.appId) {
                            $memberNames += $m.AdditionalProperties.appId
                        } else {
                            $memberNames += $m.Id
                        }
                    }
                    $groupMembers = $memberNames -join ", "
                }
            }
        }
    }

    # Apply custom assignment type label
    $assignmentLabel = ($assignmentTypes -join " + ")
    if ($assignmentLabel -eq "DirectoryRole + PIM Active + PIM Eligible") {
        $assignmentLabel = "PIM Eligible + Currently Elevated"
    }
    elseif ($assignmentLabel -eq "DirectoryRole + PIM Active") {
        $assignmentLabel = "Needs Review: Directory Role w/o PIM Auditing"
    }
    elseif ($assignmentLabel -eq "PIM Active" -and $objectType -eq "ServicePrincipal") {
        $assignmentLabel = "Service Principal Permanent"
    }

    # Add to final report
    $allAssignments += [PSCustomObject]@{
        Timestamp = $timestampNow
        DisplayName = $displayName
        UserPrincipalName = $userPrincipalName
        ObjectType = $objectType
	GroupMembers = $groupMembers
        RoleName = $roleName
        AssignmentTypes = $assignmentLabel
    }
}

# Export final report
$allAssignments | Export-Csv "c:\users\Public\M365AdminAccessReviewResults.csv" -NoTypeInformation

Write-Host "Report generated: M365AdminAccessReviewResults.csv"
