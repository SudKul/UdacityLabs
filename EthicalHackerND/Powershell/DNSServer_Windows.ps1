$transcriptFileName = ("{0}\{1}.txt" -f $env:TEMP, ([datetime]::Now.ToString("yy.MM.dd_hh.mm.ss")))

# Udacity's Azure App Registration details
$resourceLocation = "South Central US"                      ## It has to be "South Central US". No other regions allowed. 
$udacityLabAgentAppName = "appSpektraImagesforStudents"
$applicationId = "c2320c13-09d6-4b95-b3d3-c5d337fdfdce"
$clientSecret = "CZ08Q~q_lHJpbJKLyygAHPXvS-AeYRzShqagpabU"

# Udacity's Image details
$udacitySubscriptionId = "75011c23-45a5-4aba-bef5-48d15414dd8d"
$udacityResourceGroup = "Vendor_Spektra"
$udacityImageGalleryName = "Spektra_Machine_Images"
# $udacityImageDefinitionName = "Debianx64DMZOnCloudNewImage"
$udacityImageVersion = "1.0.0"
$tenant1 = "9441a015-f081-4b16-8111-e38c5a1de18e"

# ToDo for the Student
$UserSubscriptionId= "xxxxxxxx-xxxxxxxx-xxxxxxxx-xxxxxxxx"
$labResourceGroupName = "nd350-rg"

# Arrays - Provided by Udacity - STATIC values
$udacityImageDefinitionNameArray = @("DNSServerImage")
$vmNameArray = @("DNSServer")
$nicNameArray = @("dnsserver184")

$SubscriptionId = Get-AzSubscription -SubscriptionId $UserSubscriptionId
Set-AzContext -Subscription $SubscriptionId

$TenantId = $SubscriptionId.TenantId

  # Check the Resource Group
  $labResourceGroupLocation = $resourceLocation
  Write-Host ("`nChecking the resource group '{0}' in Azure region '{1}'" -f $labResourceGroupName, $labResourceGroupLocation)
  $rg = Get-AzResourceGroup -Name $labResourceGroupName -Location $labResourceGroupLocation -ErrorAction Ignore
  if($rg) { Write-Host "`nPerfect! the Resource group already exists! You are on the right track." }
  else
  {
    Write-Host "`nOOPS! Resource Group not found."
    return    
  }

  # Grant access to the Udacity App
  $authZUrl = ("https://login.microsoftonline.com/{0}/oauth2/authorize?client_id={1}&response_type=code&redirect_uri=https%3A%2F%2Fwww.microsoft.com%2F" -f $TenantId, $applicationId)
  $msg = "`nWe are now going to allow the Udacity VM Agent to access this subscription. Please click OK to proceed or Cancel to stop execution."

  $yes = New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Proceed with permission'
  $no = New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Cancel execution and exit.'
  $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
  $result = $host.ui.PromptForChoice('Grant permission?', $msg, $options, 0)

  Start-Process $authZUrl
  $res = Read-Host -Prompt "Please press enter once you have completed granting permission to the Udacity Lab Agent and closed the window"

  # Granting permission
  New-AzRoleAssignment -ObjectId (Get-AzADServicePrincipal -DisplayName $udacityLabAgentAppName).Id -RoleDefinitionName "Contributor" -ResourceGroupName $labResourceGroupName -ErrorAction Ignore | Out-Null  

  # Context switch and execution
  $secret = $clientSecret | ConvertTo-SecureString -AsPlainText -Force
  $cred = New-Object -TypeName PSCredential -ArgumentList $applicationId, $secret

  Clear-AzContext -Force
  # Connect to Udacity tenant
  Connect-AzAccount -ServicePrincipal -Credential $cred  -Tenant $tenant1 -Force
  # Connect to Personal Azure tenant
  $tenant2 = $TenantId
  Connect-AzAccount -ServicePrincipal -Credential $cred -Tenant $tenant2 -Force

try
{
  # Loop
  For ($i=0; $i -lt $vmNameArray.Length; $i++) {      
    Write-Host "`nLoop $i started!"
    # Set a variable for the image version in Tenant 1 using the full image ID of the shared image version
    $image = ("/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Compute/galleries/{2}/images/{3}/versions/{4}" -f $udacitySubscriptionId, $udacityResourceGroup, $udacityImageGalleryName, $udacityImageDefinitionNameArray[$i], $udacityImageVersion)

    # Get the existing NIC
    $nic = Get-AzNetworkInterface -Name $nicNameArray[$i] -ResourceGroupName $labResourceGroupName 

    # Set VM config, and create a virtual machine
    $osDiskName = $vmNameArray[$i]
    $vmConfig = New-AzVMConfig -VMName $vmNameArray[$i] -VMSize Standard_B1s
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -Id $image
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name "$osDiskName-os-disk" -StorageAccountType "Standard_LRS" -CreateOption FromImage
    $vmConfig = Set-AzVMBootDiagnostic -VM $vmConfig -Disable
    
    $vm = New-AzVM -ResourceGroupName $labResourceGroupName -Location $labResourceGroupLocation -VM $vmConfig -Verbose

    if($vm) { Write-Host "`nSUCCESS! $i " }
    else
    {
      Write-Host "`nOOPS! VM $i not created! Exiting the Loop."   
      return 
    }
  }
  Write-Host "`nLoop completed."
}
catch
{
  $line = $_.InvocationInfo.ScriptLineNumber

  "Error was in Line $($line) and was: `n $($_)"
}
