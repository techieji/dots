export def main [] {
  let res = cat /sys/class/graphics/*/modes | parse "U:{width}x{height}p-0"
  let width = $res.width.0 | into int
  let height = $res.height.0 | into int

  let bw = ($width * 0.1) | into int      # Calibrate, depends on avizo's settings
  let bh = ($height * 0.1) | into int
  let x = ($width / 2 - $bw / 2) | into int
  let y = ($height / 2 - $bh / 2) | into int

  let s = $"($x),($y) ($bw)x($bh)"

  let mean = grim -g $s -t ppm - | pamsumm -mean | parse "the mean of all samples is {mean}"
  ($mean.mean.0 | into float) < 50
}
