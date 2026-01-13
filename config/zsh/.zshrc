# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# --- CONFIGURACIÓN OH MY ZSH (¡ESTO FALTABA!) ---
export ZSH="$HOME/.oh-my-zsh"

# Tema (Usamos el archivo directo como tenías, es válido)
source ~/powerlevel10k/powerlevel10k.zsh-theme

# Plugins (Ahora sí funcionarán porque cargamos OMZ abajo)
plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting)

# Cargar Oh My Zsh (Esta es la línea mágica que te faltaba)
source $ZSH/oh-my-zsh.sh

# --- ALIAS ---
# bat
alias cat='bat'
alias catn='bat --style=plain'
alias catnp='bat --style=plain --paging=never'
 
# lsd
alias ll='lsd -lh --group-dirs=first'
alias la='lsd -a --group-dirs=first'
alias l='lsd --group-dirs=first'
alias lla='lsd -lha --group-dirs=first'
alias ls='lsd --group-dirs=first'

# --- HISTORIAL ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt histignorealldups sharehistory

# --- FUNCIONES PROPIAS ---

# CORREGIDO: Cambiado /home/s4vitar por /home/owen (o $HOME)
function settarget(){
    ip_address=$1
    machine_name=$2
    echo "$ip_address $machine_name" > $HOME/.config/bin/target
}

function cleartarget(){
	echo '' > $HOME/.config/bin/target
}

# --- PATHS ---
export PATH=/opt/kitty/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/games:/usr/games:/usr/sbin/:/opt/nvim/bin

# --- CONFIGURACIÓN P10K ---
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
