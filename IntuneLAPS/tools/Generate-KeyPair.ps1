# generate keypair
$RSA = New-Object System.Security.Cryptography.RSACryptoServiceProvider(2048)
$publicKey = [System.Convert]::ToBase64String($RSA.ExportCspBlob(0))
$privateKey = [System.Convert]::ToBase64String($RSA.ExportCspBlob(1))

# write keys to files
$fileNameSuffix = "$((Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")).key"
$publicKey | Out-File -FilePath ([System.IO.Path]::Combine($PSScriptRoot, "public_key_$($fileNameSuffix)"))
$privateKey | Out-File -FilePath ([System.IO.Path]::Combine($PSScriptRoot, "private_key_$($fileNameSuffix)"))

# write to console
Write-Host @"
+--------------+
| Public Key   |
+--------------+
$($publicKey)

+--------------+
| Private Key  |
+--------------+
$($privateKey)

"@
