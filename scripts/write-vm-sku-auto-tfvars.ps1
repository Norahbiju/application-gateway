$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$skuJson = & PowerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "get-vm-sku.ps1")

if ($LASTEXITCODE -ne 0) {
  throw "Failed to select a VM SKU with Azure CLI."
}

$skuResult = $skuJson | ConvertFrom-Json

if (-not $skuResult.vm_size) {
  throw "Azure CLI SKU lookup returned an empty VM size."
}

$tfvarsPath = Join-Path $repoRoot "terraform.auto.tfvars.json"
$tfvarsJson = @{
  vm_size = $skuResult.vm_size
} | ConvertTo-Json

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tfvarsPath, $tfvarsJson, $utf8NoBom)

Write-Host "Selected VM size '$($skuResult.vm_size)' for location '$($skuResult.location)' and wrote $tfvarsPath"
