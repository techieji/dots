#! /usr/bin/env nu
# Adapted version of avizo's lightctl to use hyprsunset for brightness

# Usage:
#   Raise brightness: lightctl.nu -- +5
#   Lower brightness: lightctl.nu -- -5

def is-dark [] {
  let res = cat /sys/class/graphics/*/modes | parse "U:{width}x{height}p-0"
  let width = $res.width.0 | into int
  let height = $res.height.0 | into int

  let bw = ($width * 0.1) | into int      # Calibrate, depends on avizo's settings
  let bh = ($height * 0.1) | into int
  let x = ($width / 2 - $bw / 2) | into int
  let y = ($height / 2 - $bh / 2) | into int

  let s = $"($x),($y) ($bw)x($bh)"

  let mean = grim -g $s -t ppm - | pamsumm -mean -brief | into float
  $mean < 50
}

def main [delta: string] {
  hyprctl hyprsunset gamma $delta
  let level = hyprctl hyprsunset gamma | into int
  let resource = (
    if ($level < 33) { "brightness_low" }
    else if ($level < 66) { "brightness_medium" }
    else { "brightness_high" }
  )
  let res = is-dark
  if $res {
    let res = ($"($resource)_dark")
    print $res
    avizo-client --image-resource=($res) --progress=($level / 100)
  } else {
    print $resource
    avizo-client --image-resource=($resource) --progress=($level / 100)
}
}
