Trace-VstsEnteringInvocation $MyInvocation

$VariableName = Get-VstsInput -Name variableName -Require
$Operation = Get-VstsInput -Name operation -Require
$StepString = Get-VstsInput -Name step -Require

$oldValueString = (Get-Item env:$VariableName).Value
[int]$oldValue = [convert]::ToInt32($oldValueString, 10)

[int]$Step = [convert]::ToInt32($StepString, 10)

switch ($Operation)
{
    "increment"
    {
        $newValue = $oldValue + $Step
    }
    "decrement"
    {
        $newValue = $oldValue - $Step
    }
    Default {}
}

Write-Host ("##vso[task.setvariable variable={0};]{1}" -f $VariableName, $newValue)
Write-Output ("Variable '{0}' is updated from '{1}' to '{2}'" -f $VariableName, $oldValue, $newValue)

Trace-VstsLeavingInvocation $MyInvocation