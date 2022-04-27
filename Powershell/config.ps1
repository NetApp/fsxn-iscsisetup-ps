#Variable File
$Prefix = "netapp"

#Enter the drive letter to be used for storing log folder in RDS Custom Instance (e.g. G,H,I etc.)
$LogFolderDriveLetter = "J"
$S3BucketName = "s3-bucket-name"
$S3FileKey = "SnapCenter4.6.exe"         #File Key for the Snapcenter Server installer file from the S3 bucket
$S3PemFile = "key.pem"         #AWS pem key (Format - key-name.pem)


#OS Type - windows or linux, specify windows_2008 if not sure
$OsType= "windows_2008"

#Id of the private subnets in Availability Zone (e.g., subnet-a0246dcd).
$PrivateSubnet1ID = "subnet-****"
$PrivateSubnet2ID = "subnet-****"
$SubnetRouteTableId = "rtb-****"

#FSx ONTAP Variables
$FsxFileSystemId = "fs-*****"
$FsxSvmId = "svm-****"
$SVMName = "svm-****"
$SvmMgmtIp = "1.1.1.1"
$FsxSvmIscsiIP1 = "1.1.1.1"
$FsxSvmIscsiIP2 = "1.1.1.1"
$FsxAdminPassword = "password"
$FsxMgmtIP = "1.1.1.1"

$LunSizeData = 10
$LunSizeLog = 20
$LunSizeSnapInfo = 30

#VPC Variables
$VPCID = "vpc-****"
$SecurityGroupId = "sg-****"


$AwsAccessKey = "****"
$AwsSecretKey = "****"
$AwsRegion = "us-east-1"
$CustomRdsEC2InstanceId = "i-****"
$CustomRdsEC2InstanceIP = "1.1.1.1"
$SnapCenterWindowsEC2InstanceId = "i-****"
