$transcriptFileName = ("{0}\{1}.txt" -f $env:TEMP, ([datetime]::Now.ToString("yy.MM.dd_hh.mm.ss")))

# Udacity's Azure App Registration details
$resourceLocation = "South Central US"
$udacityLabAgentAppName = "appSpektraImagesforStudents"
$applicationId = "c2320c13-09d6-4b95-b3d3-c5d337fdfdce"
$clientSecret = "CZ08Q~q_lHJpbJKLyygAHPXvS-AeYRzShqagpabU"

# Udacity's Image details
$udacitySubscriptionId = "75011c23-45a5-4aba-bef5-48d15414dd8d"
$udacityResourceGroup = "Vendor_Spektra"
$udacityImageGalleryName = "Spektra_Machine_Images"
$udacityImageDefinitionName = "Debianx64DMZOnCloudNewImage"
$udacityImageVersion = "1.0.0"
$tenant1 = "9441a015-f081-4b16-8111-e38c5a1de18e"

# ToDo for the Student
$UserSubscriptionId= "cb8b28bf-cbe1-4648-9a3b-82aab5f9d651"
# Provide RG details
$labResourceGroupName = "nd350-southcentral"

# ToDo for the Student
# Resources details
$vmName = "Debianx64DMZOnCloudNew"
$myNetworkSecurityGroup = "myNSG"
$myNetworkSecurityGroupRuleRDP = "myNSGRDP"
$myNicName = "myNIC"
$vnetName = "MigrateVM-vnet"
$mySubnetName = "mySubnet"


$SubscriptionId = Get-AzSubscription -SubscriptionId $UserSubscriptionId
Set-AzContext -Subscription $SubscriptionId

$TenantId = $SubscriptionId.TenantId



  #Create the Lab Resource Group

  $labResourceGroupLocation = $resourceLocation

  Write-Host ("`nInitializing resource group '{0}' in Azure region '{1}'" -f $labResourceGroupName, $labResourceGroupLocation)

  $rg = Get-AzResourceGroup -Name $labResourceGroupName -Location $labResourceGroupLocation -ErrorAction Ignore


  if($rg) { Write-Host "Resource group already exists" }
  else
  {

    $rg = New-AzResourceGroup -Name $labResourceGroupName -Location $labResourceGroupLocation -Tag @{AppCode="UDACITY"; ContentType='LAB'; CourseName='MLND'}

  }

  #region Grant access to the Udacity App

  $authZUrl = ("https://login.microsoftonline.com/{0}/oauth2/authorize?client_id={1}&response_type=code&redirect_uri=https%3A%2F%2Fwww.microsoft.com%2F" -f $TenantId, $applicationId)


  $msg = "`nWe are now going to allow the Udacity VM Agent to access this subscription. Please click OK to proceed or Cancel to stop execution."

  $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Proceed with permission'
  $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel execution and exit.'
  $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

  $result = $host.ui.PromptForChoice('Grant permission?', $msg, $options, 0)


  Start-Process $authZUrl



  $res = Read-Host -Prompt "Please press enter once you have completed granting permission to the Udacity Lab Agent and Closed the window"


  #granting permission to....
  New-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -DisplayName $udacityLabAgentAppName).Id -RoleDefinitionName "Contributor" -ResourceGroupName $labResourceGroupName -ErrorAction Ignore | Out-Null

  #endregion

  #region Context switch and execution



  $secret = $clientSecret | ConvertTo-SecureString -AsPlainText -Force
  $cred = New-Object -TypeName PSCredential -ArgumentList $applicationId, $secret


  Clear-AzContext -Force
   #udacity
  Connect-AzAccount -ServicePrincipal -Credential $cred  -Tenant $tenant1 -Force

  $tenant2 = $TenantId
  Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $tenant2 -Force




  # Set a variable for the image version in Tenant 1 using the full image ID of the shared image version
  $image = ("/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/galleries/{2}/images/{3}/versions/{4}" -f $udacitySubscriptionId, $udacityResourceGroup, $udacityImageGalleryName, $udacityImageDefinitionName, $udacityImageVersion)

  # Create user object
  # Networking pieces
  
  $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $mySubnetName  -AddressPrefix "192.168.1.0/24"

  $vnet = New-AzVirtualNetwork -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -Name $vnetName -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

  $pip = New-AzPublicIpAddress -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -Name "mypublicdns$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4
  
  $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name $myNetworkSecurityGroupRuleRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

  $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -Name $myNetworkSecurityGroup -SecurityRules $nsgRuleRDP

  $nic = New-AzNetworkInterface -Name $myNicName -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize Standard_B1s | Set-AzVMSourceImage -Id $image | Add-AzVMNetworkInterface -Id $nic.Id
  
  # set OS disk type
  $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "$vmName-os-disk" -StorageAccountType "Standard_LRS"-CreateOption FromImage

  # Create a virtual machine
  New-AzVM -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -VM $vmConfig -Verbose

  # endregion


  $udacityImageDefinitionName = "Debianx64DMZwebCMSCloudImage"
  $udacityImageDefinitionName = "DMZIServerImage"