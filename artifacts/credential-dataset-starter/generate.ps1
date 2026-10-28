param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'dataset'))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$null = New-Item -ItemType Directory -Force -Path $OutputDirectory
$records = @()
$firstNames = @('Alex', 'Sam', 'Jamie', 'Robin', 'Casey', 'Taylor', 'Morgan', 'Drew')
$lastNames = @('Rivera', 'Santos', 'Cruz', 'Reyes', 'Garcia', 'Flores', 'Ramos')
$qualifications = @('Basic Plumbing Training', 'Household Electrical Safety', 'Home Cleaning Training', 'Basic Carpentry Training', 'Appliance Maintenance Training')
$issuers = @('Example Skills Academy', 'Demo Learning Center', 'Sample Training Institute')
$referenceDate = [datetime]'2026-10-28'
$utf8 = New-Object System.Text.UTF8Encoding $false
for ($i = 1; $i -le 100; $i++) {
    $split = if ($i -le 60) { 'train' } elseif ($i -le 80) { 'validation' } else { 'test' }
    $layout = if ($i -le 60) { ($i - 1) % 3 } elseif ($i -le 80) { 3 } else { 4 }
    $id = 'synthetic_{0:D4}' -f $i
    $folder = Join-Path $OutputDirectory $split
    $null = New-Item -ItemType Directory -Force -Path $folder
    $holder = '{0} {1}' -f $firstNames[($i - 1) % $firstNames.Count], $lastNames[([int][math]::Floor(($i - 1) / $firstNames.Count)) % $lastNames.Count]
    $issuer = $issuers[($i - 1) % $issuers.Count] + ' (Fictional)'
    $qualification = $qualifications[($i - 1) % $qualifications.Count]
    $certificateNumber = if ($i % 10 -eq 0) { $null } else { 'DEMO-ONLY-{0:D5}' -f $i }
    $issued = '2024-06-{0:D2}' -f (1 + ($i % 28))
    $expires = if ($i % 10 -eq 1) { '2025-06-30' } else { '2028-06-30' }
    $profileName = if ($i % 10 -eq 2) { 'Different Demo Person' } else { $holder }
    $flags = @()
    if (!$certificateNumber) { $flags += 'missing_certificate_number' }
    if ([datetime]$expires -lt $referenceDate) { $flags += 'expired_on_reference_date' }
    if ($holder -ne $profileName) { $flags += 'holder_profile_name_mismatch' }
    $bitmap = New-Object System.Drawing.Bitmap 1100,780
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.Clear([System.Drawing.Color]::FromArgb(252,251,247))
    $accent = [System.Drawing.Color]::FromArgb((35 + $layout * 15), (70 + $layout * 12), (100 + $layout * 8))
    $pen = New-Object System.Drawing.Pen $accent,3
    $brush = New-Object System.Drawing.SolidBrush $accent
    $fontFamily = if ($layout % 2 -eq 0) { 'Arial' } else { 'Georgia' }
    $titleFont = New-Object System.Drawing.Font $fontFamily,28
    $bodyFont = New-Object System.Drawing.Font $fontFamily,18
    $smallFont = New-Object System.Drawing.Font 'Arial',14
    try {
        $graphics.DrawRectangle($pen, 25,25,1050,730)
        $graphics.DrawString('SYNTHETIC TRAINING SAMPLE - NOT A VALID CREDENTIAL', $smallFont, [System.Drawing.Brushes]::Firebrick, 60,45)
        $graphics.DrawString('Certificate of Training', $titleFont, $brush, 60,105)
        $graphics.DrawString($issuer, $bodyFont, $brush, 60,165)
        $fields = @(
            @('Holder', $holder),
            @('Qualification', $qualification),
            @('Certificate number', $(if ($certificateNumber) { $certificateNumber } else { '[not provided]' })),
            @('Issued', $issued),
            @('Expires', $expires)
        )
        $order = switch ($layout) {
            0 { @(0,1,2,3,4) }
            1 { @(2,0,1,4,3) }
            2 { @(1,0,3,4,2) }
            3 { @(0,2,4,1,3) }
            4 { @(3,4,0,2,1) }
        }
        for ($j = 0; $j -lt 5; $j++) {
            $field = $fields[$order[$j]]
            $x = 60 + ($layout * 14)
            $y = 245 + ($j * 72)
            $graphics.DrawString(($field[0] + ': ' + $field[1]), $bodyFont, [System.Drawing.Brushes]::Black, $x,$y)
        }
        $graphics.DrawString('Fictional issuer and holder. No professional license or authority granted.', $smallFont, [System.Drawing.Brushes]::Firebrick, 60,665)
        $graphics.DrawString(('Sample ID: ' + $id + ' | Layout: ' + $layout), $smallFont, $brush, 60,705)
        $path = Join-Path $folder ($id + '.png')
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $titleFont.Dispose(); $bodyFont.Dispose(); $smallFont.Dispose()
        $brush.Dispose(); $pen.Dispose(); $graphics.Dispose(); $bitmap.Dispose()
    }
    $record = [ordered]@{
        sample_id = $id
        image = "$split/$id.png"
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        split = $split
        layout_id = "fictional_layout_$layout"
        source = 'programmatically_generated'
        is_synthetic = $true
        document_type = 'fictional_training_certificate'
        fields = [ordered]@{
            holder_name = $holder
            issuer = $issuer
            qualification = $qualification
            certificate_number = $certificateNumber
            issue_date = $issued
            expiration_date = $expires
        }
        context = @{ provider_profile_name = $profileName; reference_date = '2026-10-28' }
        expected_rule_flags = @($flags)
        authenticity = 'unknown_not_evaluated'
    }
    $records += [pscustomobject]$record
}
foreach ($split in @('train', 'validation', 'test')) {
    $lines = @($records | Where-Object { $_.split -eq $split } | ForEach-Object { $_ | ConvertTo-Json -Depth 8 -Compress })
    [System.IO.File]::WriteAllLines((Join-Path $OutputDirectory ($split + '.jsonl')), [string[]]$lines, $utf8)
}
Write-Output 'Created 100 synthetic PNGs and labels: 60 train, 20 validation, 20 test.'
