Add-Type -AssemblyName System.Drawing
$app = 'C:\Users\kmkor\KotoLang\app'
$sheet = [System.Drawing.Bitmap]::new(760, 260)
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(255, 235, 236, 240))
$g.InterpolationMode = 'HighQualityBicubic'
$g.SmoothingMode = 'AntiAlias'

# The legacy icons at the size they actually appear.
$x = 20
foreach ($d in @('mdpi','hdpi','xhdpi','xxhdpi','xxxhdpi')) {
  $b = [System.Drawing.Bitmap]::FromFile("$app\android\app\src\main\res\mipmap-$d\ic_launcher.png")
  $g.DrawImage($b, $x, 30, $b.Width, $b.Height)
  $x += $b.Width + 16
  $b.Dispose()
}

# The adaptive icon as a launcher would show it: foreground over the field,
# masked to a circle, at 48 and 96 pixels.
$fg = [System.Drawing.Bitmap]::FromFile("$app\android\app\src\main\res\drawable-xxxhdpi\ic_launcher_foreground.png")
$field = [System.Drawing.Color]::FromArgb(255, 0x21, 0x30, 0x5B)
foreach ($pair in @(@(48, 20), @(96, 90), @(192, 210))) {
  $s = $pair[0]; $ox = $pair[1]
  $tile = [System.Drawing.Bitmap]::new($s, $s)
  $tg = [System.Drawing.Graphics]::FromImage($tile)
  $tg.SmoothingMode = 'AntiAlias'
  $tg.InterpolationMode = 'HighQualityBicubic'
  $tg.Clear($field)
  # The XML insets the foreground by a further 16%.
  $inset = [int]($s * 0.16)
  $tg.DrawImage($fg, $inset, $inset, $s - $inset*2, $s - $inset*2)
  $tg.Dispose()
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddEllipse(0, 0, $s, $s)
  $masked = [System.Drawing.Bitmap]::new($s, $s)
  $mg = [System.Drawing.Graphics]::FromImage($masked)
  $mg.SmoothingMode = 'AntiAlias'
  $mg.SetClip($path)
  $mg.DrawImage($tile, 0, 0)
  $mg.Dispose()
  $g.DrawImage($masked, $ox, 150, $s, $s)
  $tile.Dispose(); $masked.Dispose()
}
$fg.Dispose()
$g.Dispose()
$sheet.Save('C:\Users\kmkor\KotoLang\icon_preview.png')
$sheet.Dispose()
'ok'
