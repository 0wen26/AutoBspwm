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
# --- 1. DEPENDENCIAS ---
function install_dependencies() {
  echo -e "\n${yellowColour}[*] Actualizando sistema e instalando dependencias (esto tardará un poco)... ${endColour}"
  
  # Redirigimos a /dev/null para que no moleste
  apt update > /dev/null 2>&1

  echo -e "   [i] Instalando librerías gráficas y de compilación..."
  apt install -y build-essential git vim xcb cmake pkg-config \
  libxcb-util0-dev libxcb-ewmh-dev libxcb-randr0-dev \
  libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-xinerama0-dev \
  libasound2-dev libxcb-xtest0-dev libxcb-shape0-dev \
  libxcb-xkb-dev libcairo2-dev libx11-xcb-dev libxcb-composite0-dev \
  libxcb-image0-dev libxcb-cursor-dev xcb-proto python3-xcbgen \
  rofi feh fzf curl wget unzip zsh \
  dunst libnotify-bin flameshot scrot lxappearance papirus-icon-theme \
  ripgrep fd-find npm python3-venv > /dev/null 2>&1
}

# --- 2. CONFIGURACIÓN (DOTFILES) ---
function install_dotfiles() {
  echo -e "\n${turquoiseColour}[*] Enlazando configuraciones desde carpeta 'config'...${endColour}"

  repo_conf_dir="$(dirname "$(readlink -f "$0")")/config"

  if [ ! -d "$repo_conf_dir" ]; then
      echo -e "${redColour}[!] Error: No encuentro la carpeta 'config'.${endColour}"
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
          
          # PERMISOS AUTOMÁTICOS
          if [ "$app_name" == "bspwm" ]; then
              chmod +x "$real_home/.config/bspwm/bspwmrc"
          fi
          if [ -d "$real_home/.config/$app_name/bin" ]; then
              chmod +x "$real_home/.config/$app_name/bin/"*
          fi
          
          # Root
          mkdir -p /root/.config
          rm -rf "/root/.config/$app_name"
          cp -r "$folder" "/root/.config/"
      fi
  done
  
  # --- FIX POLYBAR ---
  echo -e "   [i] Aplicando parches automáticos a Polybar..."
  mkdir -p "$real_home/.config/bin"
  touch "$real_home/.config/bin/target" 2>/dev/null

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

  repo_conf_dir="$(dirname "$(readlink -f "$0")")/config"

  # ---------------------------------------------------------
  # A) INSTALACIÓN PARA EL USUARIO (OWEN)
  # ---------------------------------------------------------
  
  # 1. Instalar Oh My Zsh (Usuario)
  if [ ! -d "$real_home/.oh-my-zsh" ]; then
      echo -e "   [i] Instalando Oh My Zsh para $real_user..."
      su - "$real_user" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' > /dev/null 2>&1
  fi

  # 2. Instalar Powerlevel10k (DIRECTAMENTE EN ~/powerlevel10k)
  # Usamos esta ruta porque es la que tienes definida en tu .zshrc
  p10k_dir="$real_home/powerlevel10k"
  
  if [ ! -d "$p10k_dir" ]; then
      echo -e "   [i] Descargando P10k en $p10k_dir..."
      git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" > /dev/null 2>&1
  fi

  # 3. Plugins (Usuario)
  zsh_custom="$real_home/.oh-my-zsh/custom/plugins"
  git clone https://github.com/zsh-users/zsh-autosuggestions.git "$zsh_custom/zsh-autosuggestions" > /dev/null 2>&1
  git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/zsh-syntax-highlighting" > /dev/null 2>&1

  # 4. Enlazar Configuración (Usuario)
  if [ -f "$repo_conf_dir/zsh/.zshrc" ]; then
      echo -e "   [i] Aplicando tu configuración personal (Usuario)..."
      ln -sf "$repo_conf_dir/zsh/.zshrc" "$real_home/.zshrc"
      ln -sf "$repo_conf_dir/zsh/.p10k.zsh" "$real_home/.p10k.zsh"
  else
      # Fallback básico
      sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' "$real_home/.zshrc"
  fi

  # ---------------------------------------------------------
  # B) INSTALACIÓN PARA ROOT (MODO DIABLO 🔥)
  # ---------------------------------------------------------
  
  echo -e "   [i] Configurando entorno para ROOT..."

  # 1. Instalar Oh My Zsh para ROOT
  if [ ! -d "/root/.oh-my-zsh" ]; then
      git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /root/.oh-my-zsh > /dev/null 2>&1
  fi

  # 2. Plugins para ROOT (Copiamos los del usuario)
  mkdir -p /root/.oh-my-zsh/custom/plugins
  cp -r "$zsh_custom/zsh-autosuggestions" /root/.oh-my-zsh/custom/plugins/ 2>/dev/null
  cp -r "$zsh_custom/zsh-syntax-highlighting" /root/.oh-my-zsh/custom/plugins/ 2>/dev/null

  # 3. Powerlevel10k para ROOT
  # Copiamos la carpeta del usuario a /root/powerlevel10k para mantener la estructura
  if [ ! -d "/root/powerlevel10k" ]; then
      cp -r "$p10k_dir" "/root/powerlevel10k"
  fi

  # 4. Aplicar Archivos de Configuración ROOT (Desde config/root)
  if [ -d "$repo_conf_dir/root" ]; then
      echo -e "   [i] Copiando dotfiles de ROOT (.zshrc, .p10k.zsh, .bashrc)..."
      
      # Copiamos si existen
      [ -f "$repo_conf_dir/root/.zshrc" ] && cp "$repo_conf_dir/root/.zshrc" "/root/.zshrc"
      [ -f "$repo_conf_dir/root/.p10k.zsh" ] && cp "$repo_conf_dir/root/.p10k.zsh" "/root/.p10k.zsh"
      [ -f "$repo_conf_dir/root/.bashrc" ] && cp "$repo_conf_dir/root/.bashrc" "/root/.bashrc"
  else
      echo -e "   [!] No encontré carpeta 'config/root'. Usando configuración básica."
      cp "$real_home/.zshrc" "/root/.zshrc"
      cp "$real_home/.p10k.zsh" "/root/.p10k.zsh"
  fi

  # ---------------------------------------------------------
  # FINALIZACIÓN
  # ---------------------------------------------------------

  # Cambiar Shell por defecto
  chsh -s $(which zsh) "$real_user" > /dev/null 2>&1
  chsh -s $(which zsh) root > /dev/null 2>&1
  
  # Arreglar permisos del usuario (Fundamental)
  chown -R "$real_user:$real_user" "$real_home/.oh-my-zsh" "$real_home/.zshrc" "$real_home/.p10k.zsh" "$p10k_dir"

  echo -e "${greenColour}[+] ZSH configurado para Usuario y Root.${endColour}"
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
    echo -e "${yellowColour}[!] Descargando Hack Nerd Font de internet...${endColour}"
    wget -q "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip" -O Hack.zip
    unzip -o Hack.zip -d "$fonts_dest" > /dev/null 2>&1
    rm Hack.zip
    fc-cache -v > /dev/null 2>&1
  fi
}

# --- 5. BSPWM & SXHKD ---
function install_bspwm_sxhkd() {
  echo -e "\n${blueColour}[*] Compilando e Instalando BSPWM y SXHKD...${endColour}"
  cd /usr/local/src
  rm -rf bspwm sxhkd

  # Silenciamos git
  git clone https://github.com/baskerville/bspwm.git > /dev/null 2>&1
  git clone https://github.com/baskerville/sxhkd.git > /dev/null 2>&1

  cd bspwm
  make > /dev/null 2>&1
  make install > /dev/null 2>&1
  cp contrib/freedesktop/bspwm.desktop /usr/share/xsessions/

  cd ../sxhkd
  make > /dev/null 2>&1
  make install > /dev/null 2>&1

  cd ~
  echo -e "${greenColour}[+] BSPWM y SXHKD listos.${endColour}"
}

# --- 6. POLYBAR ---
function install_polybar() {
  echo -e "\n${purpleColour}[*] Compilando Polybar (esto tarda unos segundos)...${endColour}"
  apt install -y libuv1-dev libxml2-dev > /dev/null 2>&1

  cd /usr/local/src
  rm -rf polybar
  git clone --recursive https://github.com/polybar/polybar.git > /dev/null 2>&1

  cd polybar
  mkdir build && cd build
  cmake .. -DBUILD_DOC=OFF -DENABLE_CURL=OFF > /dev/null 2>&1
  make -j$(nproc) > /dev/null 2>&1
  make install > /dev/null 2>&1

  echo -e "${greenColour}[+] Polybar instalada.${endColour}"
}

# --- 7. PICOM ---
function install_picom() {
  echo -e "\n${purpleColour}[+] Compilando Picom...${endColour}"
  # Deps extra silenciosas
  apt install -y libconfig-dev libdbus-1-dev libegl-dev libev-dev libepoxy-dev \
    libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev libxcb-composite0-dev \
    libxcb-damage0-dev libxcb-glx0-dev libxcb-image0-dev libxcb-present-dev \
    libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev libxcb-shape0-dev \
    libxcb-util-dev libxcb-xfixes0-dev meson ninja-build uthash-dev > /dev/null 2>&1

  cd /usr/local/src
  rm -rf picom
  git clone https://github.com/yshui/picom.git > /dev/null 2>&1
  cd picom
  meson setup --buildtype=release build > /dev/null 2>&1
  ninja -C build > /dev/null 2>&1
  ninja -C build install > /dev/null 2>&1

  echo -e "${greenColour}[+] Picom instalado.${endColour}"
}

# --- 8. KITTY ---
function install_kitty() {
  echo -e "\n${blueColour}[*] Instalando Kitty Terminal...${endColour}"
  cd /opt
  # wget -q es modo silencioso
  wget -q "https://github.com/kovidgoyal/kitty/releases/download/v0.45.0/kitty-0.45.0-x86_64.txz" -O kitty.txz
  
  rm -rf kitty
  mkdir -p kitty
  tar -xf kitty.txz -C kitty > /dev/null 2>&1
  rm kitty.txz

  ln -sf /opt/kitty/bin/kitty /usr/local/bin/kitty
  ln -sf /opt/kitty/bin/kitten /usr/local/bin/kitten
  
  cp /opt/kitty/share/applications/kitty.desktop /usr/share/applications/
  sed -i 's|Icon=kitty|Icon=/opt/kitty/share/icons/hicolor/256x256/apps/kitty.png|g' /usr/share/applications/kitty.desktop
  sed -i 's|Exec=kitty|Exec=/opt/kitty/bin/kitty|g' /usr/share/applications/kitty.desktop

  echo -e "${greenColour}[+] Kitty instalada.${endColour}"
}

# --- 9. NEOVIM ---
# --- 9. NEOVIM + LAZYVIM ---
function install_neovim() {
  echo -e "\n${blueColour}[*] Instalando Neovim y LazyVim...${endColour}"
  cd /opt
  
  # 1. Instalar binario (Silencioso)
  wget -q "https://github.com/neovim/neovim/releases/download/v0.11.5/nvim-linux-x86_64.tar.gz" -O nvim.tar.gz
  rm -rf nvim
  tar -xzf nvim.tar.gz > /dev/null 2>&1
  
  extracted_dir=$(find . -maxdepth 1 -type d -name "nvim-linux*" | head -n 1)
  if [ -n "$extracted_dir" ]; then
      mv "$extracted_dir" nvim
  fi
  rm nvim.tar.gz
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

  # 2. Configurar LazyVim (Si no tienes config propia)
  # Primero miramos si install_dotfiles ya puso algo en ~/.config/nvim
  nvim_config_dir="$real_home/.config/nvim"
  
  if [ -d "$nvim_config_dir" ] && [ "$(ls -A $nvim_config_dir)" ]; then
      echo -e "   [i] Detectada configuración propia de Neovim."
  else
      echo -e "   [i] No hay configuración detectada. Clonando LazyVim Starter..."
      # Hacemos backup por seguridad
      rm -rf "$nvim_config_dir" "$real_home/.local/share/nvim"
      
      # Clonamos el starter oficial
      git clone https://github.com/LazyVim/starter "$nvim_config_dir" > /dev/null 2>&1
      
      # Borramos la carpeta .git para que sea TU configuración, no un repo de ellos
      rm -rf "$nvim_config_dir/.git"
      
      chown -R "$real_user:$real_user" "$nvim_config_dir"
  fi

  echo -e "${greenColour}[+] Neovim + LazyVim instalados.${endColour}"
}

# --- 10. TOOLS EXTRA ---
function install_tools(){
  echo -e "\n${yellowColour}[+] Instalando herramientas extra (lsd, bat)...${endColour}"
  cd /usr/local/src
  
  lsd_url="https://github.com/lsd-rs/lsd/releases/download/v1.0.0/lsd_1.0.0_amd64.deb"
  wget -q "$lsd_url" -O lsd.deb && dpkg -i lsd.deb > /dev/null 2>&1 && rm lsd.deb

  bat_url="https://github.com/sharkdp/bat/releases/download/v0.24.0/bat_0.24.0_amd64.deb"
  wget -q "$bat_url" -O bat.deb && dpkg -i bat.deb > /dev/null 2>&1 && rm bat.deb
  
  echo -e "${greenColour}[+] Herramientas instaladas.${endColour}"
}

# --- 11. WALLPAPER ---
function install_wallpaper() {
  echo -e "\n${blueColour}[*] Configurando Wallpaper...${endColour}"
  
  # Usamos la variable segura que definimos al principio
  repo_wall_dir="$script_dir/wallpapers"
  user_wall_dir="$real_home/wallpapers"
  
  echo "   [i] Buscando wallpapers en: $repo_wall_dir"
  
  mkdir -p "$user_wall_dir"
  
  if [ -d "$repo_wall_dir" ]; then
      cp -r "$repo_wall_dir"/* "$user_wall_dir/"
      chown -R "$real_user:$real_user" "$user_wall_dir"
      echo -e "   [i] Wallpapers copiados del repositorio."
  else
      echo -e "   [!] No encontré la carpeta local. Descargando de internet..."
      wget -q "https://images4.alphacoders.com/936/936378.jpg" -O "$user_wall_dir/wallpaper.jpg"
  fi
  
  # Aplicar fondo inmediatamente (para comprobar que funciona)
  first_wall=$(find "$user_wall_dir" -type f \( -name "*.jpg" -o -name "*.png" \) | head -n 1)
  if [ -n "$first_wall" ]; then
      su - "$real_user" -c "DISPLAY=:0 feh --bg-fill '$first_wall'" > /dev/null 2>&1
  fi
}

# --- EJECUCIÓN ---
install_dependencies
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

echo -e "\n${greenColour}[✔] INSTALACIÓN COMPLETADA. REINICIA TU SISTEMA.${endColour}\n"
