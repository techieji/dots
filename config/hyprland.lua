{ pkgs, pabc, ... }: ''
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
local browser = "${pkgs.appimage-run}/bin/appimage-run ~/AppImages/helium.appimage"
local reader = "${pkgs.zathura}/bin/zathura"

-- Env vars ----------------

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- All config -------------

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
        inactive_opacity = 0.9,
        dim_modal = true,
        dim_inactive = false,
        dim_strength = 0.3,
        dim_special = 0.1,
        blur = {
            -- Lots of options here: https://wiki.hypr.land/Configuring/Basics/Variables/#blur
            enabled = true,
            size = 1,
            passes = 3,
        },
        shadow = {
            enabled = false
        }
    },
    animations = {
        enabled = true,
        workspace_wraparound = true
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
    }
})

-- Windowrules ------------

hl.window_rule({ name = "browser", match = { class = "helium" }, scrolling_width = 1 })
hl.window_rule({ name = "obsidian", match = { class = "obsidian" }, scrolling_width = 1 })
hl.window_rule({ name = "speedcrunch", match = { title = "SpeedCrunch" }, persistent_size = true })
hl.window_rule({ name = "xdg-desktop-portal", match = { title = "Select what to share" }, float = true })

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
hl.bind(mainMod .. "L", hl.dsp.exec_cmd("${pkgs.hyprlock}/bin/hyprlock"))
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("${pkgs.hyprlock}/bin/hyprlock & sleep 1 && ${pkgs.systemd}/bin/systemctl suspend"))
hl.bind(mainMod .. "P", hl.dsp.exec_cmd("${../scripts/password.sh}"))

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

local wpctl = "${pkgs.wireplumber}/bin/wpctl";
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-"))
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%+"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${pabc}/bin/pabc -1"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${pabc}/bin/pabc 1"))

hl.bind("XF86Calculator", hl.dsp.exec_cmd("${pkgs.speedcrunch}/bin/speedcrunch", { float = true, opacity = "0.9" }))
hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd("${pkgs.nushell}/bin/nu ${../scripts/toggle-keyboard.nu}"))
hl.bind("Print", hl.dsp.exec_cmd("${pkgs.grimblast}/bin/grimblast copy area"))

-- Gestures ---------------

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "scroll_move",
    scale = 1
})

-- Animations (copied from default config) ---------

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1}    } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1}    } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}     } })

-- Default springs
hl.curve("easy",           { type = "spring", mass = 1, stiffness = 71.2633, dampening = 15.8273644 })

hl.animation({ leaf = "global",        enabled = true,  speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true,  speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true,  speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true,  speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true,  speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true,  speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true,  speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true,  speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true,  speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true,  speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true,  speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true,  speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true,  speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "slidevert" })
hl.animation({ leaf = "specialWorkspace",    enabled = true,  speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true,  speed = 7,    bezier = "quick" })
''
