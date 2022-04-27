# AWS RDS FSx ONTAP Automation using Powershell

This Powershell script can be used to automate the integration of Netapp Fsx Ontap with Custom RDS (Relational Database Service) to allow Fsx Ontap to be used as a backend persistent storage for the database.

This template also integrates the Netapp Snapcenter software with Fsx Ontap to allow restore and backup of the data from Fsx.


## Scripts

- **rds_fsx.ps1**: Powershell script to mount FSx ONTAP volume on AWS RDS Custom Instance.

- **rds_fsx_with_snapcenter.ps1**: Powershell script to mount FSx ONTAP volume on AWS RDS Custom Instance with NetApp SnapCenter Installation and Setup.


## Pre-requisites

- AWS Powershell Module should be installed on the host you run this script from

- Custom RDS Instance and SnapCenter server instance with IAM role that includes "ssm:SendCommand", "ssm:ListCommandInvocations" and "ssm:GetCommandInvocation" permissions along with the default permissions required for RDS (https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/custom-setup-sqlserver.html#custom-setup-sqlserver.iam-vpc)

- Custom RDS Instance, SnapCenter server Instance and Fsx Ontap should be able to communicate with each other (networking and security groups need to ensure the same)

- S3 Bucket with packages.zip, fsxLambdaFunction.zip, SnapCenter executable file and a pem file uploaded to it.
  ```
  Note: packages.zip and fsxLambdaFunction.zip can be found in the Powershell/Resources folder of this repository.
  ```

- FSx Ontap File System with NTFS-enabled SVM created along with FSx and SVM passwords set

- Ensure that the user account executing this script has the access to manage SSM, IAM, EC2 VPC Endpoint, Lambda and S3.


## Parameters

| Name | Type | Description |
| --- | --- | --- |
| `Prefix` | String | (Required) LUN and volume name Prefix. |
| `LunSizeData` | Number | (Required) Size of LUN for data volume. |
| `LunSizeLog` | Number | (Required) Size of LUN for log volume. |
| `LunSizeSnapInfo` | Number | (Required) Size of LUN for RDS Log volume. |
| `LogFolderDriveLetter` | String | (Required) Drive letter to be used for storing log folder in RDS Custom Instance (e.g. G,H,I etc.) |
| `OsType` | String | (Required) OS Type - windows or linux. |
| `PrivateSubnet1ID` | String | (Required) ID of Subnet1 in Availability Zone 1. |
| `PrivateSubnet2ID` | String | (Required) ID of Subnet2 in Availability Zone 2. |
| `SubnetRouteTableId` | String | (Required) Route Table ID for S3 VPC Endpoint. |
| `VPCID` | String | (Required) ID of the AWS VPC. |
| `SecurityGroupId` | AWS::EC2::SecurityGroup::Id | (Optional) ID of the Security Group. |
| `FsxAdminPassword` | String | (Required) Password for "fsxadmin" user in FSx File System. |
| `AwsAccessKey` | String | (Required) AWS Access Key. |
| `AwsSecretKey` | String | (Required) AWS Secret Key. |
| `FsxFileSystemId` | String | (Required) ONTAP FSx File System ID. |
| `SVMName` | String | (Required) ONTAP FSx SVM Name. |
| `FsxSvmId` | String | (Required) ONTAP FSx SVM ID. |
| `SvmMgmtIp` | String | (Required) ONTAP FSx SVM Management IP. |
| `FsxSvmIscsiIP1` | String | (Required) ONTAP FSx SVM ISCSI Endpoint IP1. |
| `FsxSvmIscsiIP2` | String | (Required) ONTAP FSx SVM ISCSI Endpoint IP2. |
| `FsxMgmtIP` | String | (Required) ONTAP FSx File System Management IP. |
| `AwsRegion` | String | (Required) AWS Region. |
| `SnapCenterWindowsEC2InstanceId` | String | (Required) Windows EC2 instance ID for SnapCenter Host. |
| `InstanceProfileName` | String | (Required) Instance Profile Name for the temporary Linux EC2 Instance. |
| `CustomRdsEC2InstanceId` | String | (Required) EC2 Instance ID of the Custom RDS Instance. |
| `CustomRdsEC2InstanceIP` | String | (Required) Enter the EC2 Instance IP of the Custom RDS Instance. |
| `S3BucketName` | String | (Required) S3 bucket name which contains SnapCenter installer file, pem file and pkgs.tar file. |
| `S3FileKey` | String | (Required) File Key for the SnapCenter Server installer file from the S3 bucket. |
| `S3PemFile` | String | (Required) AWS pem key (Format - key-name.pem). |


## Procedure

In order to run the automation:
1. Open a new Powershell console.
2. Clone the repository.
    ```
    git clone https://github.com/netapp-vedantsethia/aws_rds_fsx_automation.git
    ```
3. Navigate to the desired folder
    ```
    cd Powershell
    ```

4. Update the variable values in ```config.ps1```.

5. Run the Powershell script.
    ```
    .\rds_fsx.ps1
    ```
    or
    ```
    .\rds_fsx_with_snapcenter.ps1
    ```

## License
By accessing, downloading, installing or using the content in this repository, you agree the terms of the License laid out in License file.

Note that there are certain restrictions around producing and/or sharing any derivative works with the content in this repository. Please make sure you read the terms of the License before using the content. If you do not agree to all of the terms, do not access, download or use the content in this repository.

Copyright: 2022 NetApp Inc.

## Author Information
NetApp Solutions Engineering Team
