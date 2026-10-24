{ config, inputs, lib, pkgs, system, ... }:
let
  cfg = config.services.avizoContrast;
  hyprlandPackage = inputs.hyprland.packages.${system}.hyprland;

  controller = pkgs.writeShellApplication {
    name = "avizo-contrast";
    runtimeInputs = [
      pkgs.avizo
      pkgs.gawk
      pkgs.grim
      hyprlandPackage
      pkgs.jq
      pkgs.netpbm
      pkgs.pipewire
    ];
    text = ''
      set -euo pipefail

      cache="''${XDG_RUNTIME_DIR:-/tmp}/avizo-contrast-$UID"

      icon_suffix() {
        local now cached_at suffix monitor geometry mean
        now=$(date +%s)

        if [[ -r "$cache" ]]; then
          read -r cached_at suffix < "$cache" || true
          if (( now - cached_at <= 2 )); then
            printf '%s' "$suffix"
            return
          fi
        fi

        monitor=$(hyprctl monitors -j | jq -c 'map(select(.focused))[0] // .[0]')
        geometry=$(jq -r '
          (.width / 10 | floor) as $w |
          (.height / 10 | floor) as $h |
          "\(.x + ((.width - $w) / 2 | floor)),\(.y + ((.height - $h) / 2 | floor)) \($w)x\($h)"
        ' <<< "$monitor")
        mean=$(grim -g "$geometry" -t ppm - | ppmtopgm | pamsumm -mean -brief)

        # Avizo's _dark resources are dark icons intended for light backgrounds.
        suffix=$(awk -v mean="$mean" -v threshold="${toString cfg.threshold}" \
          'BEGIN { if (mean >= threshold) print "_dark"; else print "" }')
        printf '%s %s\n' "$now" "$suffix" > "$cache"
        printf '%s' "$suffix"
      }

      show_osd() {
        local icon=$1 progress=$2
        avizo-client --image-resource="$icon$(icon_suffix)" --progress="$progress"
      }

      volume_osd() {
        local device=$1 action=$2 state level icon

        case "$action" in
          toggle-mute) wpctl set-mute "$device" toggle ;;
          up)          wpctl set-volume -l 1 "$device" 5%+ ;;
          down)        wpctl set-volume "$device" 5%- ;;
          *) echo "Unknown volume action: $action" >&2; exit 2 ;;
        esac

        state=$(wpctl get-volume "$device")
        level=$(awk '{ print $2 }' <<< "$state")
        if [[ "$state" == *MUTED* ]]; then
          icon=volume_muted
        elif awk -v level="$level" 'BEGIN { exit !(level < 0.33) }'; then
          icon=volume_low
        elif awk -v level="$level" 'BEGIN { exit !(level < 0.66) }'; then
          icon=volume_medium
        else
          icon=volume_high
        fi
        show_osd "$icon" "$level"
      }

      case "''${1:-}" in
        brightness)
          [[ $# -eq 2 ]] || { echo "Usage: avizo-contrast brightness DELTA" >&2; exit 2; }
          hyprctl hyprsunset gamma "$2"
          level=$(hyprctl hyprsunset gamma)
          if (( level < 33 )); then
            icon=brightness_low
          elif (( level < 66 )); then
            icon=brightness_medium
          else
            icon=brightness_high
          fi
          show_osd "$icon" "$(awk -v level="$level" 'BEGIN { print level / 100 }')"
          ;;
        volume)
          [[ $# -eq 3 ]] || { echo "Usage: avizo-contrast volume DEVICE ACTION" >&2; exit 2; }
          case "$2" in
            sink)   volume_osd @DEFAULT_AUDIO_SINK@ "$3" ;;
            source) volume_osd @DEFAULT_AUDIO_SOURCE@ "$3" ;;
            *) echo "Unknown volume device: $2" >&2; exit 2 ;;
          esac
          ;;
        *)
          echo "Usage: avizo-contrast {brightness DELTA|volume {sink|source} {up|down|toggle-mute}}" >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  options.services.avizoContrast = {
    enable = lib.mkEnableOption "contrast-aware Avizo icons";
    threshold = lib.mkOption {
      type = lib.types.ints.between 0 255;
      default = 128;
      description = "Mean luminance above which Avizo uses its dark icon variants.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ controller ];

    services.avizo = {
      enable = true;
      settings.default = {
        time = 1;
        block-count = 20;
        y-offset = 0.5;
        x-offset = 0.5;
        border-width = 0;
      };
    };
  };
}
