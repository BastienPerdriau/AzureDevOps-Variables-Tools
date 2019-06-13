Trace-VstsEnteringInvocation $MyInvocation

$VariableName = Get-VstsInput -Name variableName -Require
$VariableValue = Get-VstsInput -Name variableValue -Require

Write-Host ("##vso[task.setvariable variable={0};]{1}" -f $VariableName, $VariableValue)
Write-Output ("Variable '{0}' assigned with value '{1}'" -f $VariableName, $VariableValue)

Trace-VstsLeavingInvocation $MyInvocation