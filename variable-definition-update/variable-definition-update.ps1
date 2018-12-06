#
# variable-definition-update.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
	[Parameter(Mandatory=$true)]
	[string]	
	$VariableName,
	
	[Parameter(Mandatory=$true)]
	[string]
	$VariableValue,

	[Parameter(Mandatory=$true)]
	[string]
	$Token
)

# TODO Convert to TS
# TODO Use VSS Web Extension SDK to authenticate instead of token https://docs.microsoft.com/en-us/rest/api/azure/devops/?view=azure-devops-rest-5.0
# TODO Add task to increment variable value
# TODO Add task to set variable value
# TODO Add task to create/set variable value
# TODO Add option to this task to set either a hard value or a variable name to use value (with option to increment ?)

Write-Host "Starting variable-definition-update"
Trace-VstsEnteringInvocation $MyInvocation

try
{
	$ApiVersion="5.0"
	$uriRoot = $env:SYSTEM_TEAMFOUNDATIONSERVERURI
	$ProjectName = $env:SYSTEM_TEAMPROJECT
	$BuildId = $env:SYSTEM_DEFINITIONID 
	$uri = "$uriRoot$ProjectName/_apis/build/definitions?api-version=$ApiVersion"

	# Base64-encodes the Personal Access Token (PAT) appropriately
	$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "", $Token)))
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

	if ($null -eq $projectDef.variables.$valueName)
	{
		Write-Error "Unable to find a variable called '$valueName' in Project $ProjectName. Please check the config and try again." -ErrorAction Stop
	}

	# get and increment the variable in $valueName
	[int]$counter = [convert]::ToInt32($projectDef.variables.$valueName.Value, 10)
	$updatedCounter = $counter + 1
	Write-Host "Project Build Number for '$ProjectName' is $counter. Will be updating to $updatedCounter"

	# Update the value and update Azure DevOps
	$projectDef.variables.$valueName.Value = $updatedCounter.ToString()
	$projectDefJson = $projectDef | ConvertTo-Json -Depth 50 -Compress
	Write-Output ("projectDef.variables.valueName.Value" -f $projectDef.variables.$valueName.Value)

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

	Write-Host "##vso[task.setvariable variable=$valueName]$updatedCounter"
}
catch
{

}
finally
{
	Trace-VstsLeavingInvocation $MyInvocation
}

Write-Host "Ending variable-definition-update"