Trace-VstsEnteringInvocation $MyInvocation

[string]$PAT = Get-VstsInput -Name PAT -Require
[string]$VariableName = Get-VstsInput -Name variableName -Require
[string]$VariableValue = Get-VstsInput -Name variableValue -Require

# TODO Use VSS Web Extension SDK to authenticate instead of token https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-5.0
# TODO Add option to this task to set either
# - a hard value
# - a variable name to use value

# - option to take variable from definition
# - option to take variable from running build

# - option to increment the value
# - option to decrement the value
# - option to write the new value into env variables

Import-Module $env:CURRENT_TASK_ROOTDIR\src\GetAzureADToken.psm1 -DisableNameChecking
Import-Module $env:CURRENT_TASK_ROOTDIR\src\GetDeploymentUri.psm1 -DisableNameChecking

try
{
	$ApiVersion="5.0"
	$uriRoot = $env:SYSTEM_TEAMFOUNDATIONSERVERURI
	$ProjectName = $env:SYSTEM_TEAMPROJECT
	$BuildId = $env:SYSTEM_DEFINITIONID 
	$uri = "$uriRoot$ProjectName/_apis/build/definitions?api-version=$ApiVersion"

	# Base64-encodes the Personal Access Token (PAT) appropriately
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $PAT)))
	$header = @{Authorization = ("Basic {0}" -f $base64AuthInfo)}

	# Get the list of Build Definitions
	$buildDefs = Invoke-RestMethod -Uri $uri -Method Get -ContentType "application/json" -Headers $header

	# Find the build definition for this project
	$buildDef = $buildDefs.value | Where-Object { $_.id -eq $BuildId }
	if ($null -eq $buildDef)
	{
		Write-Error "Unable to find a build definition for Project '$ProjectName'. Check the config values and try again." -ErrorAction Stop
	}

	$getUrl = "$($buildDef.Url)?api-version=$ApiVersion"
	$projectDef = Invoke-RestMethod -Uri $getUrl -Method Get -ContentType "application/json" -Headers $header

	if ($null -eq $projectDef.variables.$VariableName)
	{
		Write-Error "Unable to find a variable called '$VariableName' in Project $ProjectName. Please check the config and try again." -ErrorAction Stop
	}

	# Update the value and update Azure DevOps
	$projectDef.variables.$VariableName.Value = $VariableValue
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
	Invoke-RestMethod -Method Put -Uri $putUrl -Headers $header -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($projectDefJson)) | Out-Null

	Write-Host "##vso[task.setvariable variable=$VariableName]$VariableValue"
}
catch
{

}
finally
{
	Trace-VstsLeavingInvocation $MyInvocation
}

Write-Host "Ending variable-definition-update"