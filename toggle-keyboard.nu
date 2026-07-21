brightnessctl -d *::kbd_backlight g
| into int
| ($in - 1) mod 3
| brightnessctl -d *::kbd_backlight s $in
