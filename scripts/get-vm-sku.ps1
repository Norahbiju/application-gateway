param()

$ErrorActionPreference = "Stop"

$stdin = [Console]::In.ReadToEnd()
$query = @{}
if (-not [string]::IsNullOrWhiteSpace($stdin)) {
  $query = $stdin | ConvertFrom-Json
}

$location = if ($query.location) { [string]$query.location } else { "westus" }
$preferredSizes = @(
  "Standard_D2s_v5",
  "Standard_D2as_v5",
  "Standard_B2s",
  "Standard_B2ms",
  "Standard_D2s_v4"
)

$skusJson = az vm list-skus `
  --location $location `
  --resource-type virtualMachines `
  --all `
  --output json

if ($LASTEXITCODE -ne 0) {
  throw "Azure CLI failed to list VM SKUs. Run az login and confirm access to the subscription."
}

$skus = $skusJson | ConvertFrom-Json

$availableSkus = $skus |
  Where-Object {
    $restrictions = @($_.restrictions)
    $vCpuCapability = $_.capabilities | Where-Object { $_.name -eq "vCPUs" } | Select-Object -First 1
    $architectureCapability = $_.capabilities | Where-Object { $_.name -eq "CpuArchitectureType" } | Select-Object -First 1
    $isX64 = -not $architectureCapability -or $architectureCapability.value -match "(^|,)x64($|,)"
    $restrictions.Count -eq 0 -and $vCpuCapability -and [int]$vCpuCapability.value -ge 2 -and $isX64
  }

$availableSkuNames = $availableSkus | ForEach-Object { $_.name }

$selected = $preferredSizes | Where-Object { $availableSkuNames -contains $_ } | Select-Object -First 1

if (-not $selected) {
  $selected = $availableSkus |
    ForEach-Object {
      $vCpuCapability = $_.capabilities | Where-Object { $_.name -eq "vCPUs" } | Select-Object -First 1
      $memoryCapability = $_.capabilities | Where-Object { $_.name -eq "MemoryGB" } | Select-Object -First 1
      [PSCustomObject]@{
        Name     = $_.name
        Vcpus    = [int]$vCpuCapability.value
        MemoryGB = if ($memoryCapability) { [decimal]$memoryCapability.value } else { [decimal]999 }
      }
    } |
    Where-Object { $_.Vcpus -le 2 -and $_.MemoryGB -ge 4 } |
    Sort-Object Vcpus, MemoryGB, Name |
    Select-Object -ExpandProperty Name -First 1
}

if (-not $selected) {
  $selected = $availableSkus |
    ForEach-Object {
      $vCpuCapability = $_.capabilities | Where-Object { $_.name -eq "vCPUs" } | Select-Object -First 1
      $memoryCapability = $_.capabilities | Where-Object { $_.name -eq "MemoryGB" } | Select-Object -First 1
      [PSCustomObject]@{
        Name     = $_.name
        Vcpus    = [int]$vCpuCapability.value
        MemoryGB = if ($memoryCapability) { [decimal]$memoryCapability.value } else { [decimal]999 }
      }
    } |
    Sort-Object Vcpus, MemoryGB, Name |
    Select-Object -ExpandProperty Name -First 1
}

if (-not $selected) {
  throw "No unrestricted VM SKU with at least 2 vCPUs was found in $location."
}

@{
  vm_size  = $selected
  location = $location
} | ConvertTo-Json -Compress
