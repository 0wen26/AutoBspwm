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

# Detectar usuario real (no root) para la configuración
real_user="$SUDO_USER"
real_home="/home/$real_user"

# --- 1. DEPENDENCIAS (Blindadas) ---
function install_dependencies() {
  echo -e "\n${yellowColour}[*] Actualizando sistema e instalando dependencias... ${endColour}\n"
  
  apt update

  echo -e "   [i] Instalando librerías gráficas y de compilación..."
  
  # Lista completa con los parches para Polybar, SXHKD y Picom
  apt install -y build-essential git vim xcb cmake pkg-config \
  libxcb-util0-dev libxcb-ewmh-dev libxcb-randr0-dev \
  libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-xinerama0-dev \
  libasound2-dev libxcb-xtest0-dev libxcb-shape0-dev \
  libxcb-xkb-dev libcairo2-dev libx11-xcb-dev libxcb-composite0-dev \
  libxcb-image0-dev libxcb-cursor-dev xcb-proto python3-xcbgen \
  rofi feh fzf curl wget unzip
}

# --- 2. CONFIGURACIÓN (DOTFILES) - Lógica Mejorada ---
function install_dotfiles() {
  echo -e "\n${turquoiseColour}[*] Enlazando configuraciones desde carpeta 'conf'...${endColour}\n"

  # Ruta de tus configuraciones en el repo
  repo_conf_dir="$(dirname "$(readlink -f "$0")")/conf"

  if [ ! -d "$repo_conf_dir" ]; then
      echo -e "${redColour}[!] Error: No encuentro la carpeta 'conf' en este directorio.${endColour}"
      echo -e "    Asegúrate de que la carpeta se llame 'conf' y esté junto a install.sh"
      exit 1
  fi

  # Recorremos cada carpeta dentro de 'conf' (bspwm, kitty, sxhkd...)
  for folder in "$repo_conf_dir"/*; do
      if [ -d "$folder" ]; then
          app_name=$(basename "$folder")
          
          echo -e "   [i] Configurando: ${purpleColour}$app_name${endColour}"

          # 1. Configurar para el USUARIO
          user_config_path="$real_home/.config/$app_name"
          
          # Hacemos backup si ya existe una config
          if [ -d "$user_config_path" ] || [ -L "$user_config_path" ]; then
              rm -rf "$user_config_path"
          fi
          
          # Creamos el enlace simbólico (Symlink)
          # Esto hace que ~/.config/bspwm apunte directamente a tu repo
          ln -sf "$folder" "$real_home/.config/"
          
          # 2. Configurar para ROOT (Opcional, pero útil para evitar errores visuales al usar sudo)
          root_config_path="/root/.config/$app_name"
          mkdir -p /root/.config
          if [ -d "$root_config_path" ] || [ -L "$root_config_path" ]; then
              rm -rf "$root_config_path"
          fi
          cp -r "$folder" "/root/.config/"
      fi
  done

  # Corregir permisos del usuario
  chown -R "$real_user:$real_user" "$real_home/.config"

  echo -e "${greenColour}[+] Dotfiles enlazados correctamente.${endColour}"
}

# --- 3. FUENTES ---
function install_fonts() {
  echo -e "\n${turquoiseColour}[*] Instalando fuentes...${endColour}"
  fonts_src="$(dirname "$0")/fonts"
  fonts_dest="/usr/local/share/fonts"

  if [ -d "$fonts_src" ]; then
    cp -r "$fonts_src"/* "$fonts_dest"
    fc-cache -v > /dev/null 2>&1
    echo -e "${greenColour}[+] Fuentes instaladas.${endColour}"
  else
    echo -e "${yellowColour}[!] Carpeta 'fonts' no encontrada. Descargando Hack Nerd Font...${endColour}"
    wget "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" -O Hack.zip
    unzip -o Hack.zip -d "$fonts_dest"
    rm Hack.zip
    fc-cache -v > /dev/null 2>&1
  fi
}

# --- 4. BSPWM & SXHKD ---
function install_bspwm_sxhkd() {
  echo -e "\n${blueColour}[*] Instalando BSPWM y SXHKD...${endColour}\n"
  cd /usr/local/src

  # Limpieza y clonado
  rm -rf bspwm sxhkd

  git clone https://github.com/baskerville/bspwm.git
  git clone https://github.com/baskerville/sxhkd.git

  # Compilar BSPWM
  cd bspwm && make && make install
  # Instalar sesión .desktop para que aparezca en el login
  cp contrib/freedesktop/bspwm.desktop /usr/share/xsessions/

  # Compilar SXHKD
  cd ../sxhkd && make && make install

  cd ~
  echo -e "${greenColour}[+] BSPWM y SXHKD instalados.${endColour}"
}

# --- 5. POLYBAR (Git Recursive) ---
function install_polybar() {
  echo -e "\n${purpleColour}[*] Instalando Polybar...${endColour}\n"
  
  # Dependencias extra
  apt install -y libuv1-dev libxml2-dev 2>/dev/null

  cd /usr/local/src
  rm -rf polybar

  # Clonado recursivo (VITAL)
  git clone --recursive https://github.com/polybar/polybar.git

  cd polybar
  mkdir build && cd build
  
  # Sin docs ni curl para evitar errores
  cmake .. -DBUILD_DOC=OFF -DENABLE_CURL=OFF
  make -j$(nproc)
  make install

  echo -e "${greenColour}[+] Polybar instalado.${endColour}"
}

# --- 6. PICOM ---
function install_picom() {
  echo -e "\n${purpleColour}[+] Instalando Picom...${endColour}"
  
  # Deps de Picom
  apt install -y libconfig-dev libdbus-1-dev libegl-dev libev-dev libepoxy-dev \
    libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev \
    libxcb-damage0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev \
    libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev \
    libxcb-util-dev libxcb-xfixes0-dev meson ninja-build uthash-dev

  cd /usr/local/src
  rm -rf picom
  git clone https://github.com/yshui/picom.git
  cd picom

  meson setup --buildtype=release build 
  ninja -C build
  ninja -C build install

  echo -e "${greenColour}[+] Picom instalado.${endColour}"
}

# --- 7. KITTY (Versión Github Directa) ---
function install_kitty() {
  echo -e "\n${blueColour}[*] Instalando Kitty Terminal...${endColour}\n"
  cd /opt

  wget "https://github.com/kovidgoyal/kitty/releases/download/v0.45.0/kitty-0.45.0-x86_64.txz" -O kitty.txz
  
  rm -rf kitty
  mkdir -p kitty
  tar -xf kitty.txz -C kitty
  rm kitty.txz

  # Enlaces
  ln -sf /opt/kitty/bin/kitty /usr/local/bin/kitty
  ln -sf /opt/kitty/bin/kitten /usr/local/bin/kitten
  
  # Desktop file
  cp /opt/kitty/share/applications/kitty.desktop /usr/share/applications/
  sed -i 's|Icon=kitty|Icon=/opt/kitty/share/icons/hicolor/256x256/apps/kitty.png|g' /usr/share/applications/kitty.desktop
  sed -i 's|Exec=kitty|Exec=/opt/kitty/bin/kitty|g' /usr/share/applications/kitty.desktop

  echo -e "${greenColour}[+] Kitty instalada.${endColour}"
}
# --- 8. NEOVIM (RECUPERADO) ---
function install_neovim() {
  echo -e "\n${blueColour}[*] Instalando Neovim (Stable)...${endColour}\n"
  cd /opt
  wget "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-x86_64.tar.gz" -O nvim.tar.gz

  rm -rf nvim
  tar -xzf nvim.tar.gz
  mv nvim-linux-86_64 nvim
  rm nvim.tar.gz

  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  echo -e "${greenColour}[+] Neovim instalado.${endColour}"
}
# --- 8. HERRAMIENTAS EXTRA (LSD, BAT) ---
function install_tools(){
  echo -e "\n${yellowColour}[+] Instalando herramientas extra (lsd, bat)...${endColour}"
  cd /usr/local/src

  # LSD (ls moderno)
  lsd_url="https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd_1.0.0_amd64.deb"
  wget "$lsd_url" -O lsd.deb && dpkg -i lsd.deb && rm lsd.deb

  # BAT (cat moderno)
  bat_url="https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb"
  wget "$bat_url" -O bat.deb && dpkg -i bat.deb && rm bat.deb
}

# --- 9. WALLPAPER (Desde la carpeta 'wallpapers' del repo) ---
function install_wallpaper() {
  echo -e "\n${blueColour}[*] Configurando Wallpaper...${endColour}"
  
  repo_wall_dir="$(dirname "$(readlink -f "$0")")/wallpapers"
  user_wall_dir="$real_home/Wallpapers"
  
  mkdir -p "$user_wall_dir"
  
  # Si existe la carpeta wallpapers en el repo, la usamos
  if [ -d "$repo_wall_dir" ]; then
      cp -r "$repo_wall_dir"/* "$user_wall_dir/"
      chown -R "$real_user:$real_user" "$user_wall_dir"
      echo -e "   [i] Wallpapers copiados del repositorio."
  else
      # Si no, descargamos uno por defecto
      wget -q "https://images4.alphacoders.com/936/936378.jpg" -O "$user_wall_dir/wallpaper.jpg"
  fi
}

# --- EJECUCIÓN ---
install_dependencies
install_dotfiles     
install_fonts
install_bspwm_sxhkd
install_polybar
install_picom
install_kitty
install_neovim
install_tools
install_wallpaper

echo -e "\n${greenColour}[✔] INSTALACIÓN COMPLETADA. REINICIA TU SISTEMA.${endColour}\n"
