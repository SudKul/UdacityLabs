$transcriptFileName = ("{0}\{1}.txt" -f $env:TEMP, ([datetime]::Now.ToString("yy.MM.dd_hh.mm.ss")))

# ToDo for the Student
# $UserSubscriptionId= "cb8b28bf-cbe1-4648-9a3b-82aab5f9d651" # Sudhanshu's Azure account
$UserSubscriptionId = "75011c23-45a5-4aba-bef5-48d15414dd8d"  # Udacity's Azure account
$labResourceGroupName = "nd350-rg"
$resourceLocation = "South Central US" 

$udacityImageDefinitionNameArray = @("Debianx64DMZOnCloudNewImage")
$vmNameArray = @("Debianx64DMZOnCloudNew")
$nicNameArray = @("debianx64dmzoncloudn979")

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

try
{
  $VMLocalAdminUser = "LocalAdminUser"
  $VMLocalAdminSecurePassword = ConvertTo-SecureString "Password123!" -AsPlainText -Force
  $LocationName = "South Central US"
  $ResourceGroupName = "nd350-rg"
  $ComputerName = "MyVM"
  $VMName = "MyVM"
  $VMSize = "Standard_B1s"
  $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);  
  
  # Loop
  For ($i=0; $i -le $vmNameArray.Length; $i++) {      
    Write-Host "`nLoop $i started!"

    # Get the existing NIC
    $NIC = Get-AzNetworkInterface -Name $nicNameArray[$i] -ResourceGroupName $labResourceGroupName 

    $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate -PatchMode "AutomaticByPlatform"
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2022-datacenter-azure-edition-core' -Version latest
    $VirtualMachine = Set-AzVMBootDiagnostic -VM $VirtualMachine -Disable

    $vm = New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose

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