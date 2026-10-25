{ pkgs, pabc, helium, dotsLock, ... }: ''
----- HYPRLAND CONFIG ------------

-- Monitors ----------------

hl.monitor({
    output='eDP-1',
    mode='3840x2400',
    position='0x0',
    scale = 'auto',
    bitdepth = 8
})

hl.monitor({
    output = 'weylus',
    mode = '2048x2730',
    position = 'auto',
    scale = 2
})

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1
})

-- Programs ----------------

local terminal = "${pkgs.kitty}/bin/kitty"
local menu = "${pkgs.vicinae}/bin/vicinae open"
local browser = "${helium}/bin/helium"
local reader = "${pkgs.zathura}/bin/zathura"
local lockscreen = "${dotsLock}/bin/dots-lock"

-- Autostart ---------------

---- To avoid using a login manager
hl.on("hyprland.start", function() hl.exec_cmd(lockscreen) end)

-- All config --------------

hl.config({
    -- Visual stuff ---------
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
        resize_on_border = false,
        allow_tearing = false,
        layout = "scrolling"
    },
    decoration = {
        rounding = 0,
        rounding_power = 1,
        active_opacity = 1,
        inactive_opacity = 1,
        dim_modal = true,
        dim_inactive = false,
        dim_strength = 0.3,
        dim_special = 0.1,
        screen_shader = "${../resources/shader.frag}",
        blur = {
            enabled = true,
            size = 6,
            passes = 3,
            brightness = 0.95,
            contrast = 0.90,
            vibrancy = 0.12,
            ignore_opacity = true,
            new_optimizations = true,
            xray = false,
            special = false,
            popups = true,
            popups_ignorealpha = 0.2,
        },
        shadow = {
            enabled = false
        },
        motion_blur = {
            enabled = true,
            samples = 15
        }
    },
    animations = {
        enabled = true
    },
    -- Input ----------------
    input = {
        kb_layout = "us",
        kb_variant = "",
        kb_model = "",
        kb_options = "",
        kb_rules = "",
        repeat_rate = 25,
        repeat_delay = 200,
        follow_mouse = 2,
        sensitivity = -0.2,
        touchpad = {
            disable_while_typing = false,
            natural_scroll = true
        }
    },
    cursor = {
        enable_hyprcursor = false,
        sync_gsettings_theme = true
    }
})

-- Windowrules ------------

hl.window_rule({ name = "browser", match = { class = "helium" }, scrolling_width = 1 })
hl.window_rule({ name = "obsidian", match = { class = "obsidian" }, scrolling_width = 1 })
hl.window_rule({ name = "speedcrunch", match = { title = "SpeedCrunch" }, persistent_size = true })
hl.window_rule({ name = "xdg-desktop-portal", match = { title = "Select what to share" }, float = true })

hl.layer_rule({ name = "waybar", match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.12 })
hl.layer_rule({ name = "swaync-control", match = { namespace = "swaync-control-center" }, blur = true, ignore_alpha = 0.12 })
hl.layer_rule({ name = "swaync-notification", match = { namespace = "swaync-notification-window" }, blur = true, ignore_alpha = 0.12 })
hl.layer_rule({ name = "avizo", match = { namespace = "avizo" }, blur = true, ignore_alpha = 0.12 })
hl.layer_rule({ name = "vicinae", match = { namespace = "vicinae" }, blur = true, ignore_alpha = 0.12 })
hl.layer_rule({ name = "hyprshell", match = { namespace = "hyprshell.*" }, blur = true, ignore_alpha = 0.12 })

-- Bindings ---------------

local mainMod = "SUPER +"
hl.bind(mainMod .. "Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. "C", hl.dsp.window.close())
hl.bind(mainMod .. "Z", hl.dsp.exec_cmd(reader))
hl.bind(mainMod .. "F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. "R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. "B", hl.dsp.exec_cmd(browser))
-- hl.bind(mainMod .. "Shift + B", )    -- private browsing shortcut
hl.bind(mainMod .. "M", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mainMod .. "SHIFT + M", hl.dsp.window.move({ monitor = "+1", follow = true }))
hl.bind(mainMod .. "ALT + M", hl.dsp.workspace.move({ monitor = "+1" }))
hl.bind(mainMod .. "K", hl.dsp.window.kill())
hl.bind(mainMod .. "SHIFT + down", hl.dsp.layout("expel"))
hl.bind(mainMod .. "SHIFT + up", hl.dsp.layout("consume"))
hl.bind(mainMod .. "EQUAL", hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. "MINUS", hl.dsp.layout("colresize -conf"))
hl.bind(mainMod .. "L", hl.dsp.exec_cmd(lockscreen))
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(lockscreen .. " --suspend"))
hl.bind(mainMod .. "P", hl.dsp.exec_cmd("${../scripts/password.sh}"))
hl.bind(mainMod .. "N", hl.dsp.exec_cmd("swaync-client -t -sw"))         -- TODO use pkgs

-- Workspace navigation ---

hl.bind("ALT + Tab", hl.dsp.layout("move +col"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.layout("move -col"))

hl.bind(mainMod .. "left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. "right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. "up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. "down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. "SHIFT + left", hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. "SHIFT + right", hl.dsp.layout("swapcol r"))

for i = 1, 10 do
    local key = i % 10           -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,             hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key,     hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Hotkeys ----------------

hl.bind("XF86AudioMute", hl.dsp.exec_cmd("avizo-contrast volume sink toggle-mute"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("avizo-contrast volume sink down"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("avizo-contrast volume sink up"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("avizo-contrast volume source toggle-mute"), { locked = true })

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("avizo-contrast brightness -5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("avizo-contrast brightness +5"), { locked = true, repeating = true })

hl.bind("XF86Calculator", hl.dsp.exec_cmd("${pkgs.speedcrunch}/bin/speedcrunch", { float = true, opacity = "0.9" }))
hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd("${../scripts/toggle-keyboard.nu}"))
hl.bind("Print", hl.dsp.exec_cmd("${pkgs.grimblast}/bin/grimblast copy area"))

-- Gestures ---------------

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "scroll_move",
    scale = 1
})

-- Short, restrained window transitions keep motion blur from ending abruptly.
hl.curve("windowEase", { type = "bezier", points = { {0.22, 1}, {0.36, 1} } })

hl.animation({ leaf = "global", enabled = false, speed = 1, bezier = "windowEase" })
hl.animation({ leaf = "windows", enabled = true, speed = 2.2, bezier = "windowEase" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "windowEase", style = "popin 96%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.6, bezier = "windowEase", style = "popin 96%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, bezier = "windowEase" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.2, bezier = "windowEase", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.2, bezier = "windowEase", style = "fade" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.8, bezier = "windowEase" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.4, bezier = "windowEase" })
''
