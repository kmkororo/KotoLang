Add-Type -AssemblyName System.Drawing
$cs = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public static class Icon {
  // The navy field the mark sits on. Anything close to it, and reachable from
  // the edge of the picture, is background.
  static bool IsBg(byte[] p, int i, byte br, byte bg2, byte bb) {
    int b = p[i*4], g = p[i*4+1], r = p[i*4+2];
    return Math.Abs(r - br) < 34 && Math.Abs(g - bg2) < 34 && Math.Abs(b - bb) < 34;
  }

  /// Cuts the mark out of the supplied art and returns it on a transparent
  /// canvas, trimmed to what is actually drawn.
  public static Bitmap Mark(string src, out Color bgColor) {
    Bitmap bmp;
    using (var orig = new Bitmap(src)) {
      // Trim the outer few per cent first: this art has a lighter fringe right
      // on the edge, and a fringe that is not the field colour survives the
      // key and drags the bounding box out to the whole picture.
      int mx = (int)(orig.Width * 0.03), my = (int)(orig.Height * 0.03);
      int cw = orig.Width - mx * 2, ch = orig.Height - my * 2;
      bmp = new Bitmap(cw, ch, PixelFormat.Format32bppArgb);
      using (var g = Graphics.FromImage(bmp))
        g.DrawImage(orig, new Rectangle(0, 0, cw, ch), new Rectangle(mx, my, cw, ch), GraphicsUnit.Pixel);
    }
    int w = bmp.Width, h = bmp.Height;
    var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    int len = Math.Abs(data.Stride) * h;
    byte[] px = new byte[len];
    Marshal.Copy(data.Scan0, px, 0, len);

    // Sample just inside the corner rather than on it: this art has a lighter
    // fringe on the very edge, and keying on that leaves the whole picture.
    int probe = ((int)(h * 0.05)) * w + (int)(w * 0.05);
    byte bb = px[probe*4], bg2 = px[probe*4+1], br = px[probe*4+2];
    bgColor = Color.FromArgb(br, bg2, bb);

    bool[] isBg = new bool[w * h];
    var stack = new Stack<int>();
    for (int x = 0; x < w; x++) {
      foreach (int i in new[] { x, (h - 1) * w + x })
        if (!isBg[i] && IsBg(px, i, br, bg2, bb)) { isBg[i] = true; stack.Push(i); }
    }
    for (int y = 0; y < h; y++) {
      foreach (int i in new[] { y * w, y * w + w - 1 })
        if (!isBg[i] && IsBg(px, i, br, bg2, bb)) { isBg[i] = true; stack.Push(i); }
    }
    while (stack.Count > 0) {
      int i = stack.Pop();
      int x = i % w, y = i / w;
      for (int dy = -1; dy <= 1; dy++)
        for (int dx = -1; dx <= 1; dx++) {
          int nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          int j = ny * w + nx;
          if (!isBg[j] && IsBg(px, j, br, bg2, bb)) { isBg[j] = true; stack.Push(j); }
        }
    }
    for (int i = 0; i < w * h; i++) if (isBg[i]) px[i * 4 + 3] = 0;
    Marshal.Copy(px, 0, data.Scan0, len);
    bmp.UnlockBits(data);

    int minx = w, miny = h, maxx = -1, maxy = -1;
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
        if (px[(y * w + x) * 4 + 3] > 40) {
          if (x < minx) minx = x; if (x > maxx) maxx = x;
          if (y < miny) miny = y; if (y > maxy) maxy = y;
        }
    var trimmed = new Bitmap(maxx - minx + 1, maxy - miny + 1, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(trimmed))
      g.DrawImage(bmp, new Rectangle(0, 0, trimmed.Width, trimmed.Height),
          new Rectangle(minx, miny, trimmed.Width, trimmed.Height), GraphicsUnit.Pixel);
    bmp.Dispose();
    return trimmed;
  }

  /// The mark centred on a square canvas, filling [fill] of it. Pass a
  /// transparent background for an adaptive-icon foreground layer.
  public static Bitmap Compose(Bitmap mark, int size, double fill, Color? bg) {
    var outBmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(outBmp)) {
      if (bg.HasValue) g.Clear(bg.Value);
      g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
      double scale = (size * fill) / Math.Max(mark.Width, mark.Height);
      int mw = (int)Math.Round(mark.Width * scale), mh = (int)Math.Round(mark.Height * scale);
      g.DrawImage(mark, new Rectangle((size - mw) / 2, (size - mh) / 2, mw, mh),
          new Rectangle(0, 0, mark.Width, mark.Height), GraphicsUnit.Pixel);
    }
    return outBmp;
  }
}
'@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$src = 'C:\Users\kmkor\KotoLang\art_in\icon.jpg'
$app = 'C:\Users\kmkor\KotoLang\app'
$bg = [System.Drawing.Color]::Empty
$mark = [Icon]::Mark($src, [ref]$bg)
"mark {0}x{1}  field #{2:X2}{3:X2}{4:X2}" -f $mark.Width, $mark.Height, $bg.R, $bg.G, $bg.B

# Legacy launcher icons: the mark on its field, kept clear of the corners.
$legacy = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($d in $legacy.Keys) {
  $b = [Icon]::Compose($mark, $legacy[$d], 0.68, $bg)
  $b.Save("$app\android\app\src\main\res\mipmap-$d\ic_launcher.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

# Adaptive foreground: transparent, and small enough that the circular mask
# cannot bite into it. The XML already insets this by a further 16%.
$fg = @{ 'mdpi' = 108; 'hdpi' = 162; 'xhdpi' = 216; 'xxhdpi' = 324; 'xxxhdpi' = 432 }
foreach ($d in $fg.Keys) {
  $b = [Icon]::Compose($mark, $fg[$d], 0.78, $null)
  $b.Save("$app\android\app\src\main\res\drawable-$d\ic_launcher_foreground.png", [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

# iOS wants a single opaque square per size, no transparency and no rounding.
$ios = @(
  @(20,1),@(20,2),@(20,3),@(29,1),@(29,2),@(29,3),@(40,1),@(40,2),@(40,3),
  @(50,1),@(50,2),@(57,1),@(57,2),@(60,2),@(60,3),@(72,1),@(72,2),
  @(76,1),@(76,2),@(83.5,2),@(1024,1)
)
foreach ($i in $ios) {
  $px = [int]([math]::Round($i[0] * $i[1]))
  $b = [Icon]::Compose($mark, $px, 0.72, $bg)
  $name = if ($i[0] -eq 83.5) { "Icon-App-83.5x83.5@$($i[1])x.png" } else { "Icon-App-$($i[0])x$($i[0])@$($i[1])x.png" }
  $b.Save("$app\ios\Runner\Assets.xcassets\AppIcon.appiconset\$name", [System.Drawing.Imaging.ImageFormat]::Png)
  $b.Dispose()
}

$mark.Dispose()
"#{0:X2}{1:X2}{2:X2}" -f $bg.R, $bg.G, $bg.B
