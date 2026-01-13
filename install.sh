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

# --- 1. DEPENDENCIAS ---
function install_dependencies() {
  echo -e "\n${yellowColour}[*] Actualizando sistema e instalando dependencias... ${endColour}\n"
  apt update

  # Añadimos zsh y dependencias de red
  apt install -y build-essential git vim xcb cmake pkg-config \
  libxcb-util0-dev libxcb-ewmh-dev libxcb-randr0-dev \
  libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-xinerama0-dev \
  libasound2-dev libxcb-xtest0-dev libxcb-shape0-dev \
  libxcb-xkb-dev libcairo2-dev libx11-xcb-dev libxcb-composite0-dev \
  libxcb-image0-dev libxcb-cursor-dev xcb-proto python3-xcbgen \
  rofi feh fzf curl wget unzip zsh
}

# --- 2. CONFIGURACIÓN (DOTFILES) ---
function install_dotfiles() {
  echo -e "\n${turquoiseColour}[*] Enlazando configuraciones desde carpeta 'conf'...${endColour}\n"

  repo_conf_dir="$(dirname "$(readlink -f "$0")")/config"

  if [ ! -d "$repo_conf_dir" ]; then
      echo -e "${redColour}[!] Error: No encuentro la carpeta 'conf'.${endColour}"
      exit 1
  fi

  for folder in "$repo_conf_dir"/*; do
      if [ -d "$folder" ]; then
          app_name=$(basename "$folder")
          echo -e "   [i] Configurando: ${purpleColour}$app_name${endColour}"

          # Usuario
          user_config_path="$real_home/.config/$app_name"
          if [ -d "$user_config_path" ] || [ -L "$user_config_path" ]; then
              rm -rf "$user_config_path"
          fi
          ln -sf "$folder" "$real_home/.config/"
          
          # Root (Opcional)
          mkdir -p /root/.config
          rm -rf "/root/.config/$app_name"
          cp -r "$folder" "/root/.config/"
      fi
  done
  
  # --- FIX POLYBAR: Permisos y archivos faltantes ---
  echo -e "   [i] Aplicando correcciones a scripts de Polybar..."
  
  # 1. Dar permisos de ejecución a scripts en ~/.config/bin (si existe)
  if [ -d "$real_home/.config/bin" ]; then
      chmod +x "$real_home/.config/bin/"*
  fi

  # 2. Fix error visual /bin/cat (suele ser por falta de target.txt)
  # Creamos un archivo vacío para que no de error al leerlo
  touch "$real_home/.config/bin/target" 2>/dev/null

  # 3. Detectar Interfaz de Red (eth0 vs ens33) y parchear Polybar
  # Esto arregla el módulo de red que no aparece o da error
  default_iface=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
  if [ -n "$default_iface" ]; then
      echo -e "   [i] Interfaz detectada: $default_iface. Parcheando Polybar..."
      # Buscamos archivos .ini en polybar y reemplazamos la interfaz genérica
      find "$real_home/.config/polybar" -name "*.ini" -exec sed -i "s/interface = .*/interface = $default_iface/g" {} +
  fi

  chown -R "$real_user:$real_user" "$real_home/.config"
  echo -e "${greenColour}[+] Dotfiles enlazados y corregidos.${endColour}"
}

# --- 3. ZSH + OMZ + P10K ---
function install_zsh_omz() {
  echo -e "\n${blueColour}[*] Instalando ZSH, Oh My Zsh y Powerlevel10k...${endColour}\n"

  # 1. Instalar Oh My Zsh (Sin interacción)
  if [ ! -d "$real_home/.oh-my-zsh" ]; then
      echo -e "   [i] Instalando Oh My Zsh..."
      # Usamos 'su' para instalarlo como el usuario normal, no como root
      su - "$real_user" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
  fi

  # 2. Instalar Powerlevel10k
  p10k_dir="$real_home/.oh-my-zsh/custom/themes/powerlevel10k"
  if [ ! -d "$p10k_dir" ]; then
      echo -e "   [i] Clonando Powerlevel10k..."
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
  fi

  # 3. Plugins comunes (Autosuggestions & Syntax Highlighting)
  zsh_custom="$real_home/.oh-my-zsh/custom/plugins"
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$zsh_custom/zsh-autosuggestions" 2>/dev/null
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/zsh-syntax-highlighting" 2>/dev/null

  # 4. Enlazar .zshrc y .p10k.zsh si existen en el repo
  repo_conf_dir="$(dirname "$(readlink -f "$0")")/conf"
  
  # Buscamos si tienes los archivos de zsh en tu carpeta conf
  # A veces la gente los pone en conf/zsh/ o sueltos en conf/
  if [ -f "$repo_conf_dir/zsh/.zshrc" ]; then
      ln -sf "$repo_conf_dir/zsh/.zshrc" "$real_home/.zshrc"
      ln -sf "$repo_conf_dir/zsh/.p10k.zsh" "$real_home/.p10k.zsh"
  elif [ -f "$repo_conf_dir/.zshrc" ]; then
      ln -sf "$repo_conf_dir/.zshrc" "$real_home/.zshrc"
      ln -sf "$repo_conf_dir/.p10k.zsh" "$real_home/.p10k.zsh"
  else
      echo -e "${yellowColour}[!] No encontré .zshrc en tu repo. Usando el por defecto.${endColour}"
      # Activamos el tema powerlevel10k en el archivo por defecto
      sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' "$real_home/.zshrc"
  fi

  # 5. Cambiar shell por defecto a zsh
  chsh -s $(which zsh) "$real_user"
  chsh -s $(which zsh) root

  # Permisos
  chown -R "$real_user:$real_user" "$real_home/.oh-my-zsh" "$real_home/.zshrc" "$p10k_dir"

  echo -e "${greenColour}[+] Entorno ZSH configurado.${endColour}"
}

# --- 4. FUENTES ---
function install_fonts() {
  echo -e "\n${turquoiseColour}[*] Instalando fuentes...${endColour}"
  fonts_src="$(dirname "$0")/fonts"
  fonts_dest="/usr/local/share/fonts"

  if [ -d "$fonts_src" ]; then
    cp -r "$fonts_src"/* "$fonts_dest"
    fc-cache -v > /dev/null 2>&1
    echo -e "${greenColour}[+] Fuentes locales instaladas.${endColour}"
  else
    echo -e "${yellowColour}[!] Carpeta 'fonts' no encontrada. Descargando Hack Nerd Font...${endColour}"
    wget "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" -O Hack.zip
    unzip -o Hack.zip -d "$fonts_dest"
    rm Hack.zip
    fc-cache -v > /dev/null 2>&1
  fi
}

# --- 5. BSPWM & SXHKD ---
function install_bspwm_sxhkd() {
  echo -e "\n${blueColour}[*] Instalando BSPWM y SXHKD...${endColour}\n"
  cd /usr/local/src
  rm -rf bspwm sxhkd

  git clone https://github.com/baskerville/bspwm.git
  git clone https://github.com/baskerville/sxhkd.git

  cd bspwm && make && make install
  cp contrib/freedesktop/bspwm.desktop /usr/share/xsessions/

  cd ../sxhkd && make && make install

  cd ~
  echo -e "${greenColour}[+] BSPWM y SXHKD instalados.${endColour}"
}

# --- 6. POLYBAR ---
function install_polybar() {
  echo -e "\n${purpleColour}[*] Instalando Polybar...${endColour}\n"
  apt install -y libuv1-dev libxml2-dev 2>/dev/null

  cd /usr/local/src
  rm -rf polybar
  git clone --recursive https://github.com/polybar/polybar.git

  cd polybar
  mkdir build && cd build
  cmake .. -DBUILD_DOC=OFF -DENABLE_CURL=OFF
  make -j$(nproc)
  make install

  echo -e "${greenColour}[+] Polybar instalado.${endColour}"
}

# --- 7. PICOM ---
function install_picom() {
  echo -e "\n${purpleColour}[+] Instalando Picom...${endColour}"
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

# --- 8. KITTY ---
function install_kitty() {
  echo -e "\n${blueColour}[*] Instalando Kitty Terminal...${endColour}\n"
  cd /opt
  # Enlace directo universal
  wget "https://github.com/kovidgoyal/kitty/releases/download/v0.45.0/kitty-0.45.0-x86_64.txz" -O kitty.txz
  
  rm -rf kitty
  mkdir -p kitty
  tar -xf kitty.txz -C kitty
  rm kitty.txz

  ln -sf /opt/kitty/bin/kitty /usr/local/bin/kitty
  ln -sf /opt/kitty/bin/kitten /usr/local/bin/kitten
  
  cp /opt/kitty/share/applications/kitty.desktop /usr/share/applications/
  sed -i 's|Icon=kitty|Icon=/opt/kitty/share/icons/hicolor/256x256/apps/kitty.png|g' /usr/share/applications/kitty.desktop
  sed -i 's|Exec=kitty|Exec=/opt/kitty/bin/kitty|g' /usr/share/applications/kitty.desktop

  echo -e "${greenColour}[+] Kitty instalada.${endColour}"
}

# --- 9. NEOVIM (ARREGLADO) ---
function install_neovim() {
  echo -e "\n${blueColour}[*] Instalando Neovim (Stable)...${endColour}\n"
  cd /opt
  wget "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-x86_64.tar.gz" -O nvim.tar.gz

  # Borramos instalación previa
  rm -rf nvim
  
  # Descomprimimos
  tar -xzf nvim.tar.gz
  
  # BUSQUEDA INTELIGENTE DE CARPETA
  # Buscamos qué carpeta se acaba de crear (normalmente nvim-linux64, pero por si acaso)
  extracted_dir=$(find . -maxdepth 1 -type d -name "nvim-linux*" | head -n 1)

  if [ -n "$extracted_dir" ]; then
      mv "$extracted_dir" nvim
      echo -e "   [i] Renombrado $extracted_dir -> nvim"
  else
      echo -e "${redColour}[!] Error: No encuentro la carpeta descomprimida de Neovim.${endColour}"
  fi

  rm nvim.tar.gz

  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  echo -e "${greenColour}[+] Neovim instalado en /opt/nvim.${endColour}"
}

# --- 10. TOOLS EXTRA ---
function install_tools(){
  echo -e "\n${yellowColour}[+] Instalando herramientas extra (lsd, bat)...${endColour}"
  cd /usr/local/src
  
  lsd_url="https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd_1.0.0_amd64.deb"
  wget "$lsd_url" -O lsd.deb && dpkg -i lsd.deb && rm lsd.deb

  bat_url="https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb"
  wget "$bat_url" -O bat.deb && dpkg -i bat.deb && rm bat.deb
}

# --- 11. WALLPAPER ---
function install_wallpaper() {
  echo -e "\n${blueColour}[*] Configurando Wallpaper...${endColour}"
  repo_wall_dir="$(dirname "$(readlink -f "$0")")/wallpapers"
  user_wall_dir="$real_home/Wallpapers"
  
  mkdir -p "$user_wall_dir"
  
  if [ -d "$repo_wall_dir" ]; then
      cp -r "$repo_wall_dir"/* "$user_wall_dir/"
      chown -R "$real_user:$real_user" "$user_wall_dir"
      echo -e "   [i] Wallpapers copiados del repositorio."
  else
      wget -q "https://images4.alphacoders.com/936/936378.jpg" -O "$user_wall_dir/wallpaper.jpg"
  fi
}

# --- EJECUCIÓN ---
install_dependencies
install_dotfiles
install_zsh_omz # <--- NUEVA FUNCIÓN
install_fonts
install_bspwm_sxhkd
install_polybar
install_picom
install_kitty
install_neovim
install_tools
install_wallpaper

echo -e "\n${greenColour}[✔] INSTALACIÓN COMPLETADA. REINICIA TU SISTEMA.${endColour}\n"
