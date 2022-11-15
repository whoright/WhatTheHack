param(
    [Parameter(Mandatory = $true)]
    ${resource-group-name[rg-wth-azurecosmosdb]},
    $showDebugOutput = $false
)
${resource-group-name[rg-wth-azurecosmosdb]} = if (${resource-group-name[rg-wth-azurecosmosdb]}) { ${resource-group-name[rg-wth-azurecosmosdb]} }
else {
    'rg-wth-azurecosmosdb'
}

Write-Host "Installing bicep"
# Install Bicep
# Create the install folder
$installPath = "$env:USERPROFILE\.bicep"
$installDir = New-Item -ItemType Directory -Path $installPath -Force
$installDir.Attributes += 'Hidden'
# Fetch the latest Bicep CLI binary
(New-Object Net.WebClient).DownloadFile("https://github.com/Azure/bicep/releases/latest/download/bicep-win-x64.exe", "$installPath\bicep.exe")
# Add bicep to your PATH
$currentPath = (Get-Item -path "HKCU:\Environment" ).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
if (-not $currentPath.Contains("%USERPROFILE%\.bicep")) { setx PATH ($currentPath + ";%USERPROFILE%\.bicep") }
if (-not $env:path.Contains($installPath)) { $env:path += ";$installPath" }

# Read the bicep parameters
$parameters = (Get-Content .\WTHAzureCosmosDB.IaC\main.parameters.json | ConvertFrom-Json).parameters

# Write-Host "Deploying infrastructure"
# Deploy our infrastructure
$output = New-AzSubscriptionDeployment `
    -Name "Challenge02-PS" `
    -Location $parameters.location.value `
    -TemplateFile WTHAzureCosmosDB.IaC\main.bicep `
    -TemplateParameterFile WTHAzureCosmosDB.IaC\main.parameters.json `
    -resourceGroupName ${resource-group-name[rg-wth-azurecosmosdb]}

$bicepDeploymentOutputs = $output.Outputs

Write-Host "Building and publishing solution"
# Build and publish the solution
dotnet publish WTHAzureCosmosDB.sln -c Release -clp:ErrorsOnly
Compress-Archive -Path .\WTHAzureCosmosDB.Web\bin\Release\net6.0\publish\* deploy.zip -Force

# Publish the web app to azure and clean up
$zipPath = Get-Item .\deploy.zip | % { $_.FullName }
$suppressOutput = Publish-AzWebApp -ArchivePath $zipPath -Slot $parameters.slotName.value -Name $output.Outputs.webAppName.Value -ResourceGroupName ${resource-group-name[rg-wth-azurecosmosdb]} -Force
Remove-Item deploy.zip

echo "Building and publishing proxy func app solution"
# Build and publish the solution
cd "./WTHAzureCosmosDB.ProxyFuncApp"
dotnet publish "WTHAzureCosmosDB.ProxyFuncApp.csproj" -c "Release" -clp:ErrorsOnly
Compress-Archive -Path .\bin\Release\net6.0\publish\* deploy.zip -Force

# Publish the web app to azure and clean up
$zipPath = Get-Item .\deploy.zip | % { $_.FullName }
$suppressOutput = Publish-AzWebApp -ArchivePath $zipPath -Name $output.Outputs.proxyFuncAppName.Value -ResourceGroupName ${resource-group-name[rg-wth-azurecosmosdb]} -Force
Remove-Item deploy.zip