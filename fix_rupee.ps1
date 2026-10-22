# Fix the mojibake rupee symbol â‚¹ back to ₹ (U+20B9)
$file = "lib\screens\create_bill_screen.dart"
$content = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$mojibake = [System.Text.Encoding]::UTF8.GetString([byte[]](0xC3, 0xA2, 0xE2, 0x82, 0xAC, 0xE2, 0x84, 0xA2))
# The actual broken string is â‚¹ which is the CP1252 misread of UTF-8 ₹ bytes
# ₹ in UTF-8 is E2 82 B9
# When read as Latin-1 it becomes â‚¹
$rupee = [System.Text.Encoding]::UTF8.GetString([byte[]](0xE2, 0x82, 0xB9))
Write-Host "Rupee char: $rupee"
$count = ([regex]::Matches($content, [regex]::Escape("â‚¹"))).Count
Write-Host "Found $count occurrences of mojibake rupee"
$fixed = $content.Replace("â‚¹", $rupee)
[System.IO.File]::WriteAllText($file, $fixed, [System.Text.Encoding]::UTF8)
Write-Host "Done!"
