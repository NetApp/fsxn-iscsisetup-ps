# Copyright NetApp 2022. Developed by NetApp Solutions Engineering Team
#
# Description: This Powershell script can be used to automate
# the integration of Netapp Fsx Ontap with Custom RDS (Relational Database Service)
# to allow Fsx Ontap to be used as a backend persistent storage for the database.
# This template also integrates the Netapp Snapcenter software with Fsx Ontap
# to allow restore and backup of the data from Fsx.


# Pre-requisites for running this template

#   - AWS Powershell Module should be installed on the host you run this script from
#
#   - Custom RDS Instance and SnapCenter server instance with IAM role that
#     includes "ssm:SendCommand", "ssm:ListCommandInvocations" and
#     "ssm:GetCommandInvocation" permissions along with the default permissions
#     required for RDS (https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/custom-setup-sqlserver.html#custom-setup-sqlserver.iam-vpc)
#
#   - Custom RDS Instance, SnapCenter server Instance and Fsx Ontap should be able
#     to communicate with each other (networking and security groups need to ensure the same)
#
#   - S3 Bucket with packages.zip, fsxLambdaFunction.zip, SnapCenter executable file and a pem file uploaded to it
#
#   - Fsx Ontap File System with NTFS-enabled SVM created along with Fsx and SVM
#     passwords set
#
#   - Ensure that the user account executing this script has the access to manage SSM, IAM, EC2 VPC Endpoint, Lambda and S3.


. ./config.ps1

Start-Transcript -Path "C:\Users\Administrator\Desktop\transcript.txt"
Write-Host "Setting AWS Credentials"
try {
 Set-AWSCredential -AccessKey ${AwsAccessKey} -SecretKey ${AwsSecretKey}
 Write-Host "Credentials Set Successfully"
}
catch {
 Write-Host $_
 throw "Error Occurred while setting AWS Credentials"
}

#Custom Function
$commands = @(
 '
 Start-Transcript -Path "C:\Users\Administrator\Desktop\custom_rds_iscsi_transcript.txt"
 try{
   Write-Host "Updating Firewall Rules"
   Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False;
   Write-Host "Firewall Rules Updated"
   Write-Host "Starting ISCSI Service"
   Start-service -Name msiscsi
   Set-Service -Name msiscsi -StartupType Automatic
   Write-Host "ISCSI Service Started"
 }
 catch{
   Write-Host $_
   throw "Error Occurred during ISCSI Service Setup."
 }
 '
)

Write-Host "Sending SSM Command to Custom RDS Instance for Initial ISCSI Setup"
$ssm = Send-SSMCommand `
 -InstanceId $CustomRdsEC2InstanceId `
 -Parameter @{commands = $commands} `
 -DocumentName "AWS-RunPowerShellScript" `
 -CloudWatchOutputConfig_CloudWatchLogGroupName "NetappFsxRdsLogs" `
 -CloudWatchOutputConfig_CloudWatchOutputEnabled $true


Start-Sleep -Seconds 20
$ssm_output = Get-SSMCommandInvocation -CommandId $ssm.CommandId -Detail:$true | Select-Object -ExpandProperty CommandPlugins

if ($ssm_output.Output -Match "ERROR"){
 Write-Host "ISCSI Setup Failed with Error:"
 Write-Host $ssm_output.Output
 Write-Host "For Detailed Logs, refer to CloudWatch Logs: NetappFsxRdsLogs"
 exit
}

Write-Host "ISCSI Setup Complete"

[bool]$flag = 0


while ($flag -eq 0){
 $commands = @(
   '
   try{
     Get-InitiatorPort | select NodeAddress
   }
   catch{
     Write-Host $_
     throw "Error occurred while getting Initiator Port Address"
   }
   '
 )

 Write-Host "Sending SSM Command to Retrieve IQN"

 $response = Send-SSMCommand `
               -InstanceId $CustomRdsEC2InstanceId `
               -Parameter @{commands = $commands} `
               -DocumentName "AWS-RunPowerShellScript" `
               -CloudWatchOutputConfig_CloudWatchLogGroupName "NetappFsxRdsLogs" `
               -CloudWatchOutputConfig_CloudWatchOutputEnabled $true

 Start-Sleep -Seconds 20
 $response = Get-SSMCommandInvocation -CommandId $response.CommandId -InstanceId $CustomRdsEC2InstanceId -Details $true | Select-Object -ExpandProperty CommandPlugins

 if ($response.Output -Match "ERROR"){
   Write-Host "Failed to retrieve IQN with Error:"
   Write-Host $response.Output
   Write-Host "For Detailed Logs, refer to CloudWatch Logs: NetappFsxRdsLogs"
   exit
 }

 Write-Host "Retrieved IQN from Custom RDS Instance"

 if($response.Output.split([Environment]::NewLine).Length -gt 6){
   if ($response.Output.split([Environment]::NewLine)[6] -like 'iqn*'){
     $iqn = $response.Output.split([Environment]::NewLine)[6]
     Write-Host "Printing IQN $iqn"
     $flag = 1
   }
 }
 Start-Sleep -Seconds 2
}

$commands = @(
 '
 try{
   winrm quickconfig -quiet
   Start-Sleep -Seconds 5
   Install-WindowsFeature -name Multipath-IO -Restart
 }
 catch{
   Write-Host $_
   throw "Error occurred while setting MPIO"
 }
 '
)

Write-Host "Sending SSM Command to Install MPIO"

$ssm = Send-SSMCommand `
 -InstanceId $CustomRdsEC2InstanceId `
 -Parameter @{commands = $commands} `
 -DocumentName "AWS-RunPowerShellScript" `
 -CloudWatchOutputConfig_CloudWatchLogGroupName "NetappFsxRdsLogs" `
 -CloudWatchOutputConfig_CloudWatchOutputEnabled $true

Start-Sleep -Seconds 20
$ssm_output = Get-SSMCommandInvocation -CommandId $ssm.CommandId -Detail:$true | Select-Object -ExpandProperty CommandPlugins

if ($ssm_output.Output -Match "ERROR"){
 Write-Host "MPIO Setup Failed with Error:"
 Write-Host $ssm_output.Output
 Write-Host "For Detailed Logs, refer to CloudWatch Logs: NetappFsxRdsLogs"
 exit
}

Write-Host "MPIO Setup Complete"

#S3 Gateway Endpoint
$PolicyDocument = @"
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": "*",
     "Action": [
       "s3:GetObject",
       "s3:ListBucket",
       "s3:GetBucketLocation"
     ],
     "Resource": [
       "arn:aws:s3:::*",
       "arn:aws:s3:::*/*"
     ]
   }
 ]
}
"@

$ServiceName = "com.amazonaws."+$AwsRegion+".s3"

Write-Host "Creating New S3 VPC Endpoint"

New-EC2VpcEndpoint `
 -VpcId $VPCID `
 -PolicyDocument $PolicyDocument `
 -RouteTableId $SubnetRouteTableId `
 -ServiceName $ServiceName

Write-Host "New S3 VPC Endpoint Created"

$policy_document ="{`"Version`":`"2012-10-17`",`"Statement`":[{`"Effect`":`"Allow`",`"Action`":`"logs:CreateLogGroup`",`"Resource`":`"arn:aws:logs:*:*:*`"},{`"Effect`":`"Allow`",`"Action`":[`"logs:CreateLogStream`",`"logs:PutLogEvents`"],`"Resource`":[`"arn:aws:logs:*:*:log-group:/aws/lambda/*`"]},{`"Effect`":`"Allow`",`"Action`":[`"s3:GetBucketLocation`", `"s3:GetObject`", `"s3:ListBucket`"],`"Resource`":[`"arn:aws:s3:::*`", `"arn:aws:s3:::*/*`"]},{`"Effect`":`"Allow`",`"Action`":[`"ec2:CreateNetworkInterface`",`"ec2:DeleteNetworkInterface`",`"ec2:DescribeNetworkInterfaces`", `"ec2:DescribeRouteTables`"],`"Resource`":`"*`"}]}"

Write-Host "Creating IAM Policy"

try{
 $policy = New-IAMPolicy -PolicyName MySamplePolicy -PolicyDocument $policy_document
 Write-Host "IAM Policy for Lambda created successfully."
 Write-Host "Creating Role for Lambda."
 $trust = "{`"Version`":`"2012-10-17`",`"Statement`":[{`"Effect`":`"Allow`",`"Principal`":{`"Service`":`"lambda.amazonaws.com`"},`"Action`":`"sts:AssumeRole`"}]}"
 $role = New-IAMRole -AssumeRolePolicyDocument $trust -RoleName "LambdaExecutionRoleRDSFSX"
 Write-Host "Role for Lambda created successfully."
 Write-Host "Registering Policy with Role."
 Register-IAMRolePolicy -RoleName "LambdaExecutionRoleRDSFSX" -PolicyArn $policy.Arn
 Write-Host "Registration completed successfully."
 Start-Sleep -Seconds 5
}
catch{
 Write-Host $_
 throw "Error occurred while creating IAM Role for Lambda Function"
}

try{
 Write-Host "Creating Layer for Lambda Function."
 $layer = Publish-LMLayerVersion `
   -LayerName "pythonRequests" `
   -CompatibleArchitecture "x86_64" `
   -CompatibleRuntime "python3.9" `
   -Content_S3Bucket ${S3BucketName} `
   -Content_S3Key "packages.zip"

 Write-Host "Layer creation completed successfully."
 Write-Host "Creating Lambda Function."
 Publish-LMFunction -Description "Lambda Function for FSx setup" `
   -FunctionName "FSxLambdaFunction" `
   -BucketName ${S3BucketName} `
   -Key fsxLambdaFunction.zip `
   -Handler "iscsi_connection.lambda_handler" `
   -VpcConfig_SubnetId ${PrivateSubnet1ID},${PrivateSubnet2ID} `
   -VpcConfig_SecurityGroupId ${SecurityGroupId} `
   -Role $role.Arn `
   -Runtime python3.9 `
   -Timeout 120 `
   -Layer $layer.LayerVersionArn

 $flag = 0
 $counter = 360
 while($flag -eq 0 -and $counter -ne 0){
   Write-Output "Waiting for Lambda Function Creation.."
   $result = Get-LMFunctionConfiguration -FunctionName "FSxLambdaFunction"
   if($result.State -eq "Active"){
    $flag = 1
   }
   Start-Sleep -Seconds 10
   $counter = $counter - 10
 }

 Write-Host "Lambda Function creation completed successfully."

 $authStr = "fsxadmin:"+$FsxAdminPassword
 $Bytes = [System.Text.Encoding]::UTF8.GetBytes($authStr)
 $EncodedText =[Convert]::ToBase64String($Bytes)
 if (${OsType} -Match 'windows'){
   $os = 'windows'
 }
 else{
   $os = ${OsType}
 }
 $InputData = @{
   fsxMgmtIp = ${FsxMgmtIP}
   iqn = $iqn
   osType = $os
   osLun = ${OsType}
   svmName = ${SVMName}
   prefix = ${Prefix}
   lunSizeLog = ${LunSizeLog}
   lunSizeData = ${LunSizeData}
   lunSizeSnapInfo = ${LunSizeSnapInfo}
   auth = $EncodedText
 } | ConvertTo-Json

 Write-Host "Executing Lambda Function."
 $result = Invoke-LMFunction -FunctionName FSxLambdaFunction -Payload $InputData
 if($result.StatusCode -ne 200){
   throw "Error occurred while executing Lambda Function"
 }
 Write-Host "Lambda Function executed successfully."
}
catch{
 Write-Host $_
 throw "Error occurred while creating Lambda Function"
}

Start-Sleep -Seconds 30

#Iscsi Resource
$commands = @(
 "Start-Transcript -Path 'C:\Users\Administrator\Desktop\custom_rds_mount_transcript.txt'"
 "
 try{
   `$TargetPortals = ('${FsxSvmIscsiIP1}','${FsxSvmIscsiIP2}')
   foreach (`$TargetPortal in `$TargetPortals) {New-IscsiTargetPortal -TargetPortalAddress `$TargetPortal -TargetPortalPortNumber 3260 -InitiatorPortalAddress ${CustomRdsEC2InstanceIP}}
   New-MSDSMSupportedHW -VendorId MSFT2005 -ProductId iSCSIBusType_0x9
   1..4 | %{Foreach(`$TargetPortal in `$TargetPortals){Get-IscsiTarget | Connect-IscsiTarget -IsMultipathEnabled `$true -TargetPortalAddress `$TargetPortal -InitiatorPortalAddress ${CustomRdsEC2InstanceIP} -IsPersistent `$true} }
   Set-MSDSMGlobalDefaultLoadBalancePolicy -Policy RR
   `$disks = Get-Disk | where PartitionStyle -eq raw
   if(!`$disks){throw 'Disks not found'}
   foreach (`$disk in `$disks) {Initialize-Disk `$disk.Number}
   `$diskNumberString = Get-Disk | findstr NETAPP | findstr Online | findstr ${LunSizeSnapInfo}
   `$diskNumber = `$diskNumberString.split()[0]
   New-Partition -DiskNumber `$diskNumber -DriveLetter ${LogFolderDriveLetter} -UseMaximumSize
   Format-Volume -DriveLetter ${LogFolderDriveLetter} -FileSystem NTFS -AllocationUnitSize 65536
 }
 catch{
   Write-Host `$_
   throw 'Error occurred while mounting FSX on RDS Instance'
 }
 "
)

$ssm = Send-SSMCommand `
 -InstanceId $CustomRdsEC2InstanceId `
 -Parameter @{commands = $commands} `
 -DocumentName "AWS-RunPowerShellScript" `
 -CloudWatchOutputConfig_CloudWatchLogGroupName "NetappFsxRdsLogs" `
 -CloudWatchOutputConfig_CloudWatchOutputEnabled $true

Start-Sleep -Seconds 50
$ssm_output = Get-SSMCommandInvocation -CommandId $ssm.CommandId -Detail:$true | Select-Object -ExpandProperty CommandPlugins

if ($ssm_output.Output -Match "ERROR"){
 Write-Host "FSX Mount on RDS Failed with Error:"
 Write-Host $ssm_output.Output
 Write-Host "For Detailed Logs, refer to CloudWatch Logs: NetappFsxRdsLogs"
 exit
}

Write-Host "FSX Mount on RDS Complete"
Write-Host "Execution Complete"
