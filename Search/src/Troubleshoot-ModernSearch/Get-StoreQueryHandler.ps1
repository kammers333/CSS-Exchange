Function Get-StoreQueryHandler {
    [CmdletBinding()]
    param(
        [object]$UserInformation,
        [scriptblock]$VerboseDiagnosticsCaller
    )
    begin {
        $Server = [string]::Empty
        $ProcessId = $null
        $VerboseCaller = ${Function:DefaultVerboseCaller}
    }
    process {

        if ($null -ne $VerboseDiagnosticsCaller) {
            $VerboseCaller = $VerboseDiagnosticsCaller
        }

        $ProcessId = $UserInformation.DBWorkerID
        $Server = $UserInformation.PrimaryServer
        $MailboxGuid = $UserInformation.MailboxGuid
    }
    end {
        $obj = [PSCustomObject]@{
            Server          = $Server
            ProcessId       = $ProcessId
            IsUnlimited     = $false
            SelectPartQuery = [string]::Empty
            FromPartQuery   = [string]::Empty
            WherePartQuery  = [string]::Empty
            MailboxGuid     = $MailboxGuid
        }

        $obj | Add-Member -MemberType ScriptMethod -Name "VerboseCaller" -Value $VerboseCaller
        $obj | Add-Member -MemberType ScriptMethod -Name "WriteVerbose" -Value ${Function:WriteVerbose}
        $obj | Add-Member -MemberType ScriptMethod -Name "ResetQueryInstances" -Value ${Function:ResetQueryInstances}
        $obj | Add-Member -MemberType ScriptMethod -Name "SetSelect" -Value ${Function:SetSelect}
        $obj | Add-Member -MemberType ScriptMethod -Name "AddToSelect" -Value ${Function:AddToSelect}
        $obj | Add-Member -MemberType ScriptMethod -Name "SetFrom" -Value ${Function:SetFrom}
        $obj | Add-Member -MemberType ScriptMethod -Name "SetWhere" -Value ${Function:SetWhere}
        $obj | Add-Member -MemberType ScriptMethod -Name "AddToWhere" -Value ${Function:AddToWhere}
        $obj | Add-Member -MemberType ScriptMethod -Name "InvokeGetStoreQuery" -Value ${Function:InvokeGetStoreQuery}

        return $obj
    }
}

Function DefaultVerboseCaller {
    [CmdletBinding()]
    param(
        [string]$Message
    )

    Write-Verbose $Message
}

Function WriteVerbose {
    param(
        [object]$Message
    )

    $this.VerboseCaller($Message)
}

Function ResetQueryInstances {
    $this.IsUnlimited = $false
    $this.SelectPartQuery = [string]::Empty
    $this.FromPartQuery = [string]::Empty
    $this.WherePartQuery = [string]::Empty
}

Function SetSelect {
    param(
        [string[]]$Value
    )

    [string]$temp = $Value |
        ForEach-Object { "$_," }
    $this.SelectPartQuery = $temp.TrimEnd(",")
}

Function AddToSelect {
    param(
        [string[]]$Value
    )

    [string]$temp = $Value |
        ForEach-Object { "$_," }
    $this.SelectPartQuery = "$($this.SelectPartQuery), $($temp.TrimEnd(","))"
}

Function SetFrom {
    param(
        [string]$Value
    )

    $this.FromPartQuery = $Value
}

Function SetWhere {
    param(
        [string]$Value
    )

    $this.WherePartQuery = $Value
}

Function AddToWhere {
    param(
        [string]$Value
    )

    $this.WherePartQuery = "$($this.WherePartQuery)$Value"
}

Function InvokeGetStoreQuery {

    $query = "SELECT $($this.SelectPartQuery) FROM $($this.FromPartQuery) WHERE $($this.WherePartQuery)"
    $myParams = @{
        Server    = $this.Server
        ProcessId = $this.ProcessId
        Query     = $query
    }

    if ($this.IsUnlimited) {
        $myParams["Unlimited"] = $true
    }

    $this.WriteVerbose("Running 'Get-StoreQuery -Server $($this.Server) -ProcessId $($this.ProcessId) -Unlimited:$($this.IsUnlimited) -Query `"$query`"'")
    $result = @(Get-StoreQuery @myParams)

    if ($result.DiagnosticQueryException.Count -gt 0) {
        $this.WriteVerbose("Get-StoreQuery DiagnosticQueryException : $($result.DiagnosticQueryException)")
        Write-Error "Get-StoreQuery DiagnosticQueryException : $($result.DiagnosticQueryException)"
    } elseif ($result.DiagnosticQueryTranslatorException.Count -gt 0) {
        $this.WriteVerbose("Get-StoreQuery DiagnosticQueryTranslatorException : $($result.DiagnosticQueryTranslatorException)")
        Write-Error "Get-StoreQuery DiagnosticQueryTranslatorException : $($result.DiagnosticQueryTranslatorException)"
    }

    return $result
}