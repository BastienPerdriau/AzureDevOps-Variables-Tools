Trace-VstsEnteringInvocation $MyInvocation

$VariableName = Get-VstsInput -Name variableName -Require
$Increment = Get-VstsInput -Name increment -Require

$oldValueString = (Get-Item env:$VariableName).Value
[int]$oldValue = [convert]::ToInt32($oldValueString, 10)

$newValue = $oldValue + $Increment

Write-Host ("##vso[task.setvariable variable={0};]{1}" -f $VariableName, $newValue)
Write-Output ("Variable '{0}' is incremented from '{1}' to '{2}'" -f $VariableName, $oldValue, $newValue)