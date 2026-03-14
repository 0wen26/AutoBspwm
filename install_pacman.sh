#!/bin/bash

# --- VARIABLES DE COLORES ---
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# --- CONTROL DE ERRORES ---
function ctrl_c() {
  echo -e "\n\n${redColour}[!] Saliendo...${endColour}\n"
  exit 1
}
trap ctrl_c SIGINT

# --- VALIDACIÓN DE ROOT ---
if [ "$(id -u)" -ne 0 ]; then
  echo -e "\n${redColour}[!] Debes ejecutar este script como root (sudo).${endColour}\n"
  exit 1
fi

real_user="$SUDO_USER"
real_home="/home/$real_user"
script_dir="$(dirname "$(readlink -f "$0")")"

# --- 1. DEPENDENCIAS (Adaptado a PACMAN) ---
function install_dependencies() {
  echo -e "\n${yellowColour}[*] Actualizando sistema e instalando dependencias de Arch... ${endColour}"
  
  # Actualizar repositorios
  pacman -Sy

  # Instalación de base-devel (equivalente a build-essential) y librerías XCB/Cairo
  # En Arch, los paquetes -dev no existen, están integrados en el paquete principal
  pacman -S --needed --noconfirm base-devel git vim cmake pkgconf \
  xcb-util xcb-util-wm xcb-util-keysyms xcb-util-renderutil xcb-util-image xcb-util-cursor \
  alsa-lib libmpdclient libxcb libxkbcommon-x11 cairo pango libxml2 \
  rofi feh fzf curl wget unzip zsh xorg-server xorg-xinit xorg-xsetroot \
  dunst libnotify flameshot scrot lxappearance papirus-icon-theme \
  ripgrep fd npm python python-pip net-tools
  
  mkdir -p "$real_home/.config"
}

# --- 2. CONFIGURACIÓN (DOTFILES) ---
function install_dotfiles() {
  echo -e "\n${turquoiseColour}[*] Enlazando configuraciones desde carpeta 'config'...${endColour}"
  mkdir -p "$real_home/.config"
  repo_conf_dir="$script_dir/config"

  if [ ! -d "$repo_conf_dir" ]; then
      echo -e "${redColour}[!] Error: No encuentro la carpeta 'config'.${endColour}"
      return
  fi

  for folder in "$repo_conf_dir"/*; do
      if [ -d "$folder" ]; then
          app_name=$(basename "$folder")
          echo -e "   [i] Configurando: ${purpleColour}$app_name${endColour}"

          user_config_path="$real_home/.config/$app_name"
          [ -d "$user_config_path" ] || [ -L "$user_config_path" ] && rm -rf "$user_config_path"
          
          ln -sf "$folder" "$real_home/.config/"
          
          if [ "$app_name" == "bspwm" ]; then
              chmod +x "$real_home/.config/bspwm/bspwmrc"
          fi
          if [ -d "$real_home/.config/$app_name/bin" ]; then
              chmod +x "$real_home/.config/$app_name/bin/"*
          fi
          
          mkdir -p /root/.config
          rm -rf "/root/.config/$app_name"
          cp -r "$folder" "/root/.config/"
      fi
  done
  
  echo "   [i] Parcheando Polybar para interfaces de Arch..."
  mkdir -p "$real_home/.config/bin"
  touch "$real_home/.config/bin/target"
  default_iface=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
  if [ -n "$default_iface" ]; then
      find "$real_home/.config/polybar" -name "*.ini" -exec sed -i "s/interface = .*/interface = $default_iface/g" {} +
  fi

  chown -R "$real_user:$real_user" "$real_home/.config"
  echo -e "${greenColour}[+] Dotfiles listos.${endColour}"
}

# --- 3. ZSH + OMZ + P10K ---
function install_zsh_omz() {
  echo -e "\n${blueColour}[*] Instalando ZSH, Oh My Zsh y Powerlevel10k...${endColour}"
  repo_conf_dir="$script_dir/config"

  # Usuario
  if [ ! -d "$real_home/.oh-my-zsh" ]; then
      su - "$real_user" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  p10k_dir="$real_home/powerlevel10k"
  [ ! -d "$p10k_dir" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"

  zsh_custom="$real_home/.oh-my-zsh/custom/plugins"
  [ ! -d "$zsh_custom/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions.git "$zsh_custom/zsh-autosuggestions"
  [ ! -d "$zsh_custom/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/zsh-syntax-highlighting"

  # Root
  [ ! -d "/root/.oh-my-zsh" ] && git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /root/.oh-my-zsh
  mkdir -p /root/.oh-my-zsh/custom/plugins
  cp -r "$zsh_custom/zsh-autosuggestions" /root/.oh-my-zsh/custom/plugins/ 2>/dev/null
  cp -r "$zsh_custom/zsh-syntax-highlighting" /root/.oh-my-zsh/custom/plugins/ 2>/dev/null
  [ ! -d "/root/powerlevel10k" ] && cp -r "$p10k_dir" "/root/powerlevel10k"

  # Aplicar configs
  ln -sf "$repo_conf_dir/zsh/.zshrc" "$real_home/.zshrc"
  ln -sf "$repo_conf_dir/zsh/.p10k.zsh" "$real_home/.p10k.zsh"
  cp "$repo_conf_dir/zsh/.zshrc" "/root/.zshrc"
  cp "$repo_conf_dir/zsh/.p10k.zsh" "/root/.p10k.zsh"

  chsh -s /usr/bin/zsh "$real_user"
  chsh -s /usr/bin/zsh root
  chown -R "$real_user:$real_user" "$real_home/.oh-my-zsh" "$real_home/.zshrc" "$real_home/.p10k.zsh" "$p10k_dir"
}

# --- 4. FUENTES ---
function install_fonts() {
  echo -e "\n${turquoiseColour}[*] Instalando fuentes...${endColour}"
  fonts_dest="/usr/local/share/fonts"
  mkdir -p "$fonts_dest"
  wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" -O Hack.zip
  unzip -o Hack.zip -d "$fonts_dest"
  rm Hack.zip
  fc-cache -v
}

# --- 5. BSPWM & SXHKD (Desde GitHub como pediste) ---
function install_bspwm_sxhkd() {
  echo -e "\n${blueColour}[*] Compilando BSPWM y SXHKD...${endColour}"
  mkdir -p /usr/local/src && cd /usr/local/src
  rm -rf bspwm sxhkd
  git clone https://github.com/baskerville/bspwm.git
  git clone https://github.com/baskerville/sxhkd.git
  
  cd bspwm && make && make install
  cp contrib/freedesktop/bspwm.desktop /usr/share/xsessions/
  cd ../sxhkd && make && make install
  
  ldconfig
}

# --- 6. POLYBAR (Desde GitHub) ---
function install_polybar() {
  echo -e "\n${purpleColour}[*] Compilando Polybar...${endColour}"
  # Dependencias extra para Arch
  pacman -S --needed --noconfirm libuv libxml2 libmpdclient
  
  cd /usr/local/src
  rm -rf polybar
  git clone --recursive https://github.com/polybar/polybar.git
  cd polybar
  mkdir build && cd build
  cmake ..
  make -j$(nproc)
  make install
}

# --- 7. PICOM (Desde GitHub) ---
function install_picom() {
  echo -e "\n${purpleColour}[+] Compilando Picom...${endColour}"
  pacman -S --needed --noconfirm meson ninja libev uthash libconfig libdbus libpcre2 pixman libepoxy
  
  cd /usr/local/src
  rm -rf picom
  git clone https://github.com/yshui/picom.git
  cd picom
  meson setup --buildtype=release build
  ninja -C build install
}

# --- 8. KITTY ---
function install_kitty() {
  echo -e "\n${blueColour}[*] Instalando Kitty Terminal...${endColour}"
  # En Arch es mejor instalarlo por pacman para que gestione los drivers de Nvidia mejor
  pacman -S --needed --noconfirm kitty
}

# --- 9. NEOVIM ---
function install_neovim() {
  echo -e "\n${blueColour}[*] Instalando Neovim...${endColour}"
  pacman -S --needed --noconfirm neovim
  # Configuración de LazyVim
  nvim_config_dir="$real_home/.config/nvim"
  if [ ! -d "$nvim_config_dir" ]; then
    su - "$real_user" -c "git clone https://github.com/LazyVim/starter $nvim_config_dir"
    rm -rf "$nvim_config_dir/.git"
  fi
}

# --- 10. TOOLS EXTRA (Pacman en lugar de .deb) ---
function install_tools(){
  echo -e "\n${yellowColour}[+] Instalando herramientas extra (lsd, bat)...${endColour}"
  pacman -S --needed --noconfirm lsd bat
}

# --- 11. WALLPAPER ---
function install_wallpaper() {
  echo -e "\n${blueColour}[*] Configurando Wallpaper...${endColour}"
  user_wall_dir="$real_home/wallpapers"
  mkdir -p "$user_wall_dir"
  wget -q "https://images4.alphacoders.com/936/936378.jpg" -O "$user_wall_dir/wallpaper.jpg"
  chown -R "$real_user:$real_user" "$user_wall_dir"
}

# --- 12. HARDWARE (Audio y Bluetooth) ---
function install_hardware_tools() {
  echo -e "\n${yellowColour}[*] Instalando herramientas de hardware...${endColour}"
  # En EndeavourOS/Arch se recomienda pipewire
  pacman -S --needed --noconfirm pipewire pipewire-pulse pipewire-alsa pipewire-jack pavucontrol \
  bluez bluez-utils network-manager-applet
  
  systemctl enable bluetooth
}

# --- 13. APPS ---
function install_apps() {
  echo -e "\n${blueColour}[*] Instalando Firefox y Thunar...${endColour}"
  pacman -S --needed --noconfirm firefox thunar xarchiver
}

# --- EJECUCIÓN ---
install_dependencies
install_hardware_tools
install_apps
install_dotfiles
install_zsh_omz
install_fonts
install_bspwm_sxhkd
install_polybar
install_picom
install_kitty
install_neovim
install_tools
install_wallpaper

# Configuración final de inicio
printf "sxhkd &\nexec bspwm\n" > "$real_home/.xinitrc"
chown "$real_user:$real_user" "$real_home/.xinitrc"

echo -e "\n${greenColour}[✔] INSTALACIÓN COMPLETADA. REINICIA Y EJECUTA 'startx'.${endColour}\n"
