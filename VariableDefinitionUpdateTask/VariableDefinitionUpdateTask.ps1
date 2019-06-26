Trace-VstsEnteringInvocation $MyInvocation

[string]$VariableName = Get-VstsInput -Name variableName -Require
[string]$UseValueFrom = Get-VstsInput -Name useValueFrom -Require
[string]$OutputNewValue = Get-VstsInput -Name outputNewValue -AsBool

$ApiVersion="5.0"
$uriRoot = $env:SYSTEM_TEAMFOUNDATIONSERVERURI
$ProjectName = $env:SYSTEM_TEAMPROJECT
$BuildId = $env:SYSTEM_DEFINITIONID 
$uri = "$uriRoot$ProjectName/_apis/build/definitions?api-version=$ApiVersion"

if (!(Get-VstsTaskVariable -Name "System.AccessToken")) {
    throw ("OAuth token not found. Make sure to have 'Allow Scripts to Access OAuth Token' enabled in the build definition.
			Also, give 'Project Collection Build Service' 'Edit build pipeline' permissions")
}

$token = Get-VstsTaskVariable -Name "System.AccessToken"

# Base64-encodes the Personal Access Token (PAT) appropriately
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $token)))
$headers = @{ Authorization = ("Basic {0}" -f $base64AuthInfo) }

# Get the list of Build Definitions
$buildDefs = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $headers

# Find the build definition for this project
$buildDef = $buildDefs.value | Where-Object { $_.id -eq $BuildId }
if ($null -eq $buildDef)
{
	Write-Error "Unable to find a build definition for Project '$ProjectName'. Check the config values and try again." -ErrorAction Stop
}

$getUrl = "$($buildDef.Url)?api-version=$ApiVersion"
$projectDef = Invoke-RestMethod -Uri $getUrl -Method Get -ContentType "application/json" -Headers $headers

if ($null -eq $projectDef.variables.$VariableName)
{
	Write-Error "Unable to find a variable called '$VariableName' in Project $ProjectName. Please check the config and try again." -ErrorAction Stop
}

switch ($UseValueFrom) {
	"pipelineDefinition"
	{
		$oldValueString = $projectDef.variables.$VariableName.Value
	}
	"pipelineExecution"
	{
		$oldValueString = (Get-Item env:$VariableName).Value
	}
	{($_ -eq "pipelineDefinition") -or ($_ -eq "pipelineExecution")}
	{
		[string]$IntegerOperation = Get-VstsInput -Name integerOperation -Require
		
		[int]$oldValue = [convert]::ToInt32($oldValueString, 10)

		$StepString = Get-VstsInput -Name step -Require
		[int]$Step = [convert]::ToInt32($StepString, 10)
		
		switch ($IntegerOperation)
		{
			"increment"
			{
				$newValue = $oldValue + $Step
			}
			"decrement"
			{
				$newValue = $oldValue - $Step
			}
		}
	}
	"customValue"
	{
		$newValue = Get-VstsInput -Name variableValue -Require
	}
}

# Update the value and update Azure DevOps
$projectDef.variables.$VariableName.Value = $newValue
$projectDefJson = $projectDef | ConvertTo-Json -Depth 50 -Compress
Write-Output ("projectDef.variables.VariableName.Value" -f $projectDef.variables.$VariableName.Value)

# build the URL to cater for if the Project Definition URL already has parameters or not.
$separator = "?"
if ($projectDef.Url -like '*?*')
{
	$separator = "&"
}
$putUrl = "$($projectDef.Url)$($separator)api-version=$ApiVersion"
Write-Verbose "Updating Project Build number with URL: $putUrl"
Write-Output $projectDef.variables
Write-Output (ConvertFrom-Json $projectDefJson)
Write-Output "--------------------------"
Invoke-RestMethod -Method Put -Uri $putUrl -Headers $headers -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($projectDefJson)) | Out-Null

if ($OutputNewValue)
{
	Write-Host "##vso[task.setvariable variable=$VariableName]$newValue"
}

Trace-VstsLeavingInvocation $MyInvocation