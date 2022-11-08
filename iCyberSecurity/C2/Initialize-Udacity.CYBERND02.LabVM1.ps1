$transcriptFileName = ("{0}\{1}.txt" -f $env:TEMP, ([datetime]::Now.ToString("yy.MM.dd_hh.mm.ss")))

$resourceLocation = "East US2"
$udacityLabAgentAppName = "Udacity CYBERND01 Student VM Agent"



Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

try
{

  Start-Transcript -Verbose -Path $transcriptFileName


  #region init

  if (Get-Module -Name AzureRM -ListAvailable)
  {
    Write-Warning -Message "`nAz module not installed. Having both the AzureRM and Az modules installed at the same time is not supported; Please uninstall the AzureRM modules and retry this script (or retry the script on another host where AzureRm modules are not installed`n"
  }
  elseif (Test-Path "$($env:ProgramFiles)\WindowsPowerShell\Modules\Az" -ErrorAction Ignore)#(Get-Module -Name Az -ListAvailable)
  {
    Write-Verbose "`nAz Module is already installed`n" -Verbose
  }
  else
  {

    $msg = "`nAz Module is NOT currently installed; do you want to install it?"

    $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Proceed with installation'
    $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel execution and exit.'
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

    $result = $host.ui.PromptForChoice('Install Az Module?', $msg, $options, 0)

    switch ($result)
    {

      0 {

        Write-Host "User chose to proceed with Az module installation...please wait..."

        Install-Module -Name Az -AllowClobber -Scope AllUsers -Force -Verbose

      }

      1 {
        Write-Host "User chose to not install the required Module Az. Execution will halt and exit"
        return
      }
    }

  }

  #endregion


  Import-Module AZ -Force

  Clear-AzContext -Force

  Connect-AzAccount



  #region Subscription selection

  #Connect-AzAccount

  $subs = Get-AzSubscription

  if($subs -eq $null) { throw "No subscription found" }

  if($subs.Count -eq 1)
  {
    $subTenantId = $subs[0].TenantId
    $subName = $subs[0].Name
    $subId = $subs[0].SubscriptionId
  }
  else
  {
    $msg = "`nMultiple Azure Subscriptions were found; Please select which one to use:"

    [int]$subCtr = 0

    $choice = New-Object System.Management.Automation.Host.ChoiceDescription ("Subscription &{0} ({1})" -f [char](65 + $subCtr), $subs[$subCtr].Name), ("Select {0} for subscription: {1}" -f  [char](65 + $subCtr), $subs[$subCtr].Name)

    $options = [System.Management.Automation.Host.ChoiceDescription[]]($choice)


    for ($subCtr = 1; $subCtr -lt $subs.Count; $subCtr += 1)
    {
      $choice = New-Object System.Management.Automation.Host.ChoiceDescription ("Subscription &{0} ({1})" -f [char](65 + $subCtr), $subs[$subCtr].Name), ("Select {0} for subscription: {1}" -f  [char](65 + $subCtr), $subs[$subCtr].Name)

      $options = $options + $choice
    }


    $result = $host.ui.PromptForChoice('Install Az Module?', $msg, $options, 0)

    $subTenantId = $subs[$result].TenantId
    $subName = $subs[$result].Name
    $subId = $subs[$result].SubscriptionId
  }

  #endregion


  Set-AzContext -Subscription $subId

  Write-Host "Registering Azure provider namespaces, if applicable...please wait."

  $providerNamespaces = @(Get-AzResourceProvider -ListAvailable) | ? {$_.RegistrationState -eq "NotRegistered" } | Select-Object ProviderNamespace

  $providerNamespaces | ForEach-Object {

    Write-Verbose $_.ProviderNamespace

    Register-AzResourceProvider -ProviderNamespace $_.ProviderNamespace | Out-Null
  }



  #Create the Lab Resource Group

  $labResourceGroupName = "UDACITY-CYBERND02-PROJECT1"
  $labResourceGroupLocation = $resourceLocation
  $applicationId = '91db5e13-2118-410b-80e6-9ab3eac4e20a'

  Write-Host ("`nInitializing resource group '{0}' in Azure region '{1}'" -f $labResourceGroupName, $labResourceGroupLocation)

  $rg = Get-AzResourceGroup -Name $labResourceGroupName -Location $labResourceGroupLocation -ErrorAction Ignore

  if($rg) { Write-Host "Resource group already exists" }
  else
  {

    $rg = New-AzResourceGroup -Name $labResourceGroupName -Location $labResourceGroupLocation -Tag @{AppCode="UDACITY"; ContentType='LAB'; CourseName='CYBERND02'}

  }

  #region Grant access to the Udacity App

  $authZUrl = ("https://login.microsoftonline.com/{0}/oauth2/authorize?client_id={1}&response_type=code&redirect_uri=https%3A%2F%2Fwww.microsoft.com%2F" -f $subTenantId, $applicationId)


  $msg = "`nWe are now going to allow the Udacity VM Agent to access this subscription. Please click OK to proceed or Cancel to stop execution."

  $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Proceed with permission'
  $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel execution and exit.'
  $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)

  $result = $host.ui.PromptForChoice('Grant permission?', $msg, $options, 0)

  switch ($result)
  {

    0 {

      Write-Host "User chose to proceed with granting permission...please wait..."
    }

    1 {
      Write-Host "User chose to not grant permission. Execution will halt and exit"
      return
    }
  }


  Start-Process $authZUrl



  $res = Read-Host -Prompt "Please press enter once you have completed granting permission to the Udacity Lab Agent and Closed the window"


  #granting permission to....
  New-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -DisplayName $udacityLabAgentAppName).Id -RoleDefinitionName "Contributor" -ResourceGroupName $labResourceGroupName -ErrorAction Ignore | Out-Null

  #endregion


  #region Context switch and execution

  $udacitySubscriptionId = "75011c23-45a5-4aba-bef5-48d15414dd8d"
  $udacityResourceGroup = "ICYBER-ND02-PUBLISH"
  $udacityImageGalleryName = "CYBERND02"
  $udacityImageDefinitionName = "CYBERND02-Student-StudentVM1"
  $udacityImageVersion = "1.0.0"

  $clientSecret = "wvzz-4WPyaD._D-jk1HwSsiJ6c6pew~H~0"

  $secret = $clientSecret | ConvertTo-SecureString -AsPlainText -Force
  $cred = New-Object -TypeName PSCredential -ArgumentList $applicationId, $secret


  Clear-AzContext -Force
  $tenant1 = "9441a015-f081-4b16-8111-e38c5a1de18e" #udacity
  Connect-AzAccount -ServicePrincipal -Credential $cred  -Tenant $tenant1 -Force

  $tenant2 = $subTenantId
  Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $tenant2 -Force


  $vmName = "CYBERND0201"

  # Set a variable for the image version in Tenant 1 using the full image ID of the shared image version
  $image = ("/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/galleries/{2}/images/{3}/versions/{4}" -f $udacitySubscriptionId, $udacityResourceGroup, $udacityImageGalleryName, $udacityImageDefinitionName, $udacityImageVersion)

  # Create user object
  # Networking pieces
  $mySubnetName = "subnet"
  $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $mySubnetName  -AddressPrefix "192.168.1.0/24"

  $vnetName = "vnet"
  $vnet = New-AzVirtualNetwork -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -Name $vnetName -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

  $pip = New-AzPublicIpAddress -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -Name "mypublicdns$(Get-Random)" -AllocationMethod Static -IdleTimeoutInMinutes 4

  $myNetworkSecurityGroupRuleRDP = "rdpnsgrule"
  $nsgRuleRDP = New-AzNetworkSecurityRuleConfig -Name $myNetworkSecurityGroupRuleRDP  -Protocol Tcp -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 -Access Allow

  $myNetworkSecurityGroup = "mynsg"
  $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -Name $myNetworkSecurityGroup -SecurityRules $nsgRuleRDP

  $myNicName = "nicName"
  $nic = New-AzNetworkInterface -Name $myNicName -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

  $vmConfig = New-AzVMConfig -VMName $vmName -VMSize Standard_B1s | Set-AzVMSourceImage -Id $image | Add-AzVMNetworkInterface -Id $nic.Id
  # set OS disk type
  $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "$vmName-os-disk" -StorageAccountType "Standard_LRS"-CreateOption FromImage

  # Create a virtual machine
  New-AzVM -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -VM $vmConfig -Verbose

  #endregion


}
catch
{
  $line = $_.InvocationInfo.ScriptLineNumber

  "Error was in Line $($line) and was: `n $($_)"
}
finally
{

  Stop-Transcript -ErrorAction Ignore
}


