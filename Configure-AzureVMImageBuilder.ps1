# Get existing context
$currentAzContext = Get-AzContext

# Get your current subscription ID. 
$subscriptionID = $currentAzContext.Subscription.Id

# Destination image resource group
$imageResourceGroup="rg-aibwinsig"

# Location
$location="eastus"

# Image distribution metadata reference name
$runOutputName="aibCustomWindows7Image"

# Image template name
$imageTemplateName="aibCustomWindows7ImageTemplateVer17"

# The Image Template File Name
$templateFilePath = "armTemplateWinSIG_New.json"

# Image gallery name
$sigGalleryName= "scrapaper_SharedImageGallery"

# Image definition name
$imageDefName ="customWindows7Image"

# additional replication region
$replRegion2="eastus2"

New-AzResourceGroupDeployment `
-ResourceGroupName $imageResourceGroup `
-TemplateFile $templateFilePath `
-imageTemplateName $imageTemplateName `
-location $location

Invoke-AzResourceAction `
-ResourceName $imageTemplateName `
-ResourceGroupName $imageResourceGroup `
-ResourceType Microsoft.VirtualMachineImages/imageTemplates `
-ApiVersion "2020-02-14" `
-Action Run `
-Force