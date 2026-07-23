#! /usr/bin/env nu
# Adapted version of avizo's lightctl to use hyprsunset for brightness

# Usage:
#   Raise brightness: lightctl.nu -- +5
#   Lower brightness: lightctl.nu -- -5

def main [delta: string] {
  hyprctl hyprsunset gamma $delta
  let level = hyprctl hyprsunset gamma | into int
  let resource = (
    if ($level < 33) { "brightness_low" }
    else if ($level < 66) { "brightness_medium" }
    else { "brightness_high" }
  )
  avizo-client --image-resource=($resource) --progress=($level / 100)
}
