# Cozytile zsh bits. Add to ~/.zshrc:   source ~/.config/cozytile/zsh/cozytile.zsh
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cozytile/generated/starship.toml"
command -v starship >/dev/null && eval "$(starship init zsh)"

alias ff='fastfetch -c ${XDG_CONFIG_HOME:-$HOME/.config}/cozytile/generated/fastfetch/config.jsonc'
alias viz='cava -p ${XDG_CONFIG_HOME:-$HOME/.config}/cozytile/generated/cava/config'

# cozytheme            -> print current;  cozytheme sakura | everforest | wallpaper | next
cozytheme() {
  local d="${XDG_CONFIG_HOME:-$HOME/.config}/cozytile"
  case "${1:-}" in
    "") qs -c cozytile ipc call theme get 2>/dev/null || echo "shell not running" ;;
    next) qs -c cozytile ipc call theme next ;;
    *) "$d/theme-apply.sh" "$1" ;;
  esac
}
