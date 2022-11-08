#PowerShell script to register resource providers

#Install's and import's the Az Module
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Set-PSRepository -Name "PSGallery" -Installationpolicy Trusted
Install-Module -Name Az -AllowClobber -Scope AllUsers -Force
Import-Module -Name Az

Connect-AzAccount

# ToDo for the Student: Enter the subscription name you want to use
$SubscriptionName= 'Pay-As-You-Go'


# ToDo for the Student: Enter the subscription ID you want to use
Select-AzSubscription -SubscriptionId "cb8b28bf-cbe1-4648-9a3b-82aab5f9d651"

$rps = Get-AzResourceProvider -ListAvailable | Where-Object { $_.ProviderNamespace -like "microsoft*"}

foreach($rp in $rps)
{
Register-AzResourceProvider -ProviderNamespace $rp.ProviderNamespace
}
