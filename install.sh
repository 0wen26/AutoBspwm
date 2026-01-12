#!/bin/bash

# --- CABECERA ---
# La primera línea (Shebang) le dice al sistema: "Usa bash para leer esto".

# --- VARIABLES DE COLORES ---
# En Bash, los colores son códigos de escape raros.
# Definirlos en variables hace el código leíble y profesional.
# \e[0m resetea el color al final para no pintar toda la terminal.

greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# --- FUNCIÓN DE CONTROL (Ctrl+C) ---
# Esta función se ejecutará si el usuario aprieta Ctrl+C para cancelar.
# Es muy importante limpiar la pantalla y salir ordenadamente.

function ctrl_c() {
  echo -e "\n\n${redColour}[!] Saliendo...${endColour}\n"
  exit 1
}

# 'trap' es un comando que "atrapa" señales. SIGINT es la señal de Ctrl+C.
trap ctrl_c SIGINT

# --- INICIO DEL SCRIPT ---

echo -e "\n${greenColour}[*] Comenzando la instalación del entorno...${endColour}\n"

# Aquí irá nuestra lógica más adelante...
#
if [ "$(id -u)" -ne 0 ]; then
  echo -e "\n${redColour}[!] Debes ejecutar este script como root (sudo).${endColour}\n"
  exit 1
fi

# ... (aquí sigue el "Comenzando la instalación") ...
#
# --- FUNCIÓN DE DEPENDENCIAS ---
#
function install_dependencies() {
    echo -e "\n${yellowColour}[*] Comprobando distribución y dependencias... ${endColour}\n"
    
    if grep -iq "Parrot" /etc/os-release; then
        apt update
    else
        apt update
    fi

    echo -e "   [i] Instalando TODAS las dependencias necesarias..."
    
    # HE AÑADIDO: libxcb-xkb-dev (VITAL para sxhkd) y libcairo2-dev (VITAL para polybar)
    apt install -y build-essential git vim xcb cmake pkg-config \
    libxcb-util0-dev libxcb-ewmh-dev libxcb-randr0-dev \
    libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-xinerama0-dev \
    libasound2-dev libxcb-xtest0-dev libxcb-shape0-dev \
    libxcb-xkb-dev libcairo2-dev libx11-xcb-dev libxcb-composite0-dev
}

# --- FUNCIÓN INSTALAR DOTFILES (CONFIGURACIÓN) ---
#
function install_dotfiles() {
  echo -e "\n${turquoiseColour}[*] Copiando archivos de configuración (Dotfiles)...${endColour}\n"

  # Verificamos sudo
  if [ -z "$SUDO_USER" ]; then
    echo -e "${redColour}[!] Error: No se detectó el usuario real. ¿Ejecustaste con sudo?${endColour}"
    exit 1
  fi

  real_user_home="/home/$SUDO_USER"
  config_src="$(dirname "$0")/config"

  # --- AQUÍ ENTRAMOS A LA CARPETA CONFIG ---
  cd "$config_src" || exit 1

  echo -e "   [i] Copiando configuraciones para el usuario: ${purpleColour}$SUDO_USER${endColour}"
  mkdir -p "$real_user_home/.config"
  cp -r * "$real_user_home/.config/"
  chown -R "$SUDO_USER:$SUDO_USER" "$real_user_home/.config"

  echo -e "   [i] Copiando configuraciones para el usuario ${redColour}root${endColour}"
  mkdir -p /root/.config
  cp -r * /root/.config

  echo -e "${greenColour}[+] Configuraciones copiadas.${endColour}"

  # --- ¡ESTA ES LA LÍNEA MÁGICA QUE FALTA! ---
  # Salimos de la carpeta 'config' y volvemos a la raíz del instalador
  cd .. 
}

# --- FUNCIÓN INSTALAR FUENTES ---
#
function install_fonts() {
  echo -e "\n${turquoiseColour}[*] Instalando fuentes (Hack Nerd Fonts)...${endColour}"

  # Definimos la carpeta de origen ( tu carpeta local ) y destino (sistema)
  fonts_src="$(dirname "$0")/fonts"
  fonts_dest="/usr/local/share/fonts"

  # Verificamos si tienes la carpeta fonts en tu proyecto
  if [ -d "$fonts_src" ]; then
    echo -e "   [i] Copiando fuentes desde la carpeta local..."

    # Copiamos todo lo que haya en tu carpeta fonts al destino
    cp -r "$fonts_src"/* "$fonts_dest"

    echo -e "   [i] Refrescando la caché de fuentes..."
    fc-cache -v

    echo -e "${greenColour}[+] Fuentes instaladas correctamente.${endColour}"
  else
    echo -e "${redColour}[!] Error: No encontré la carpeta 'fonts' dentro del instalador.${endColour}"
  fi

}

# --- FUNCIÓN INSTALAR BSPWM Y SXHKD ---

function install_bspwm_sxhkd() {
  echo -e "\n${blueColour}[*] Instalando BSPWM y SXHKD...${endColour}\n"

  cd /usr/local/src

  # 1. Instalar BSPWM
  if [ ! -d "bspwm" ]; then
    git clone https://github.com/baskerville/bspwm.git
  fi

  cd bspwm
  make
  make install
  
  # --- CORRECCIÓN VITAL PARA QUE APAREZCA EN EL LOGIN ---
  # Copiamos el archivo de sesión a /usr/share/xsessions (sin 'local')
  cp contrib/freedesktop/bspwm.desktop /usr/share/xsessions/
  # ------------------------------------------------------

  cd ..

  # 2. Instalar SXHKD
  if [ ! -d "sxhkd" ]; then # Espacio corregido en el corchete
    git clone https://github.com/baskerville/sxhkd.git
  fi

  cd sxhkd
  make
  make install

  cd ~
  echo -e "\n${greenColour}[+] BSPWM y SXHKD instalados correctamente.${endColour}"
}

# --- FUNCIÓN INSTALAR NEOVIM (LATEST RELEASE) ---
#
function install_neovim() {
  echo -e "\n${blueColour}[*] Instalando la última versión estable de Neovim...${endColour}\n"

  cd /usr/local/src

  # TRUCO DE EXPERTO
  # Usamos curl para ver la info de la última release.
  # Usamos grep para buscar la línea que tiene el archivo para linux de 64 bits
  # Limpiamos la URL con cut y tr

  wget_url=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest | grep "browser_download_url.*nvim-linux-x86_64.tar.gz" | cut -d : -f 2,3 | tr -d \" | head -n 1)

  echo -e "   [i] Descargando desde: $wget_url"

  # Descargamos el archivo
  wget "$wget_url" -O nvim-linux-x86_64.tar.gz

  # Descomprimimos
  tar -xzf nvim-linux-x86_64.tar.gz

  # Instalamos ( movemos la carpeta y creamos el enlace simbolico)
  # Borramos si existia una version anterior para no mezclar
  rm -rf /opt/nvim
  mv nvim-linux-x86_64 /opt/nvim

  # Creamos el acceso directo para que al escribir 'nvim' funcione
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim

  # Limpieza
  rm nvim-linux-x86_64.tar.gz

  echo -e "${greenColour}[+] Neovim instalado correctamente.${endColour}"

}

# --- FUNCIÓN INSTALAR POLYBAR (DESDE SOURCE RELEASE) ---
function install_polybar(){
    echo -e "\n${purpleColour}[*] Instalando Polybar (Git method)...${endColour}\n"

    # Dependencias extra para polybar (python-sphinx opcional, lo quitamos para evitar líos)
    apt install -y libuv1-dev libxml2-dev 2>/dev/null

    cd /usr/local/src

    # Limpieza
    rm -rf polybar* # CLONADO RECURSIVO (Soluciona el error de xpp/cmake)
    if [ ! -d "polybar" ]; then
        git clone --recursive https://github.com/polybar/polybar.git
    fi

    cd polybar
    mkdir build
    cd build
    
    # Desactivamos docs y curl para máxima compatibilidad
    cmake .. -DBUILD_DOC=OFF -DENABLE_CURL=OFF
    
    make -j$(nproc)
    make install

    echo -e "${greenColour}[+] Polybar instalado.${endColour}"
    cd ~
}


# ---- FUNCION INSTALAR PYCOM ---
function install_picom() {
  echo -e "\n${purpleColour}[+] Instalando picom (efectos visuales )...${endColour}"

  #Dependendicas para compilar picom
  apt install -y libconfig-dev libdbus-1-dev libegl-dev libev-dev libegl-dev \
    libepoxy-dev libpcre2-dev libpixman-1-dev libx11-xcb-dev libxcb1-dev \
    libxcb-composite0-dev libxcb-damage0-dev libxcb-glx0-dev libxcb-image0-dev \
    libxcb-present-dev libxcb-randr0-dev libxcb-render0-dev libxcb-render-util0-dev \
    libxcb-shape0-dev libxcb-util-dev libxcb-xfixes0-dev meson ninja-build uthash-dev

  cd /usr/local/src/

  #Clonamos el repositorio
  if [ ! -d "picom" ]; then
    git clone https://github.com/yshui/picom.git
  fi

  cd picom

  #compilacion moderna con Meson y ninja 
  meson setup --buildtype=release build 
  ninja -C build
  ninja -C build install

  echo -e "${greenColour}[+] Picom instalado.${endColour}"
}

function install_tools(){
  echo -e "\n${yellowColour}[+] Instalando herramientas extra (rofi, feh, lsd, bat)...${endColour}"

  #1. rofi, feh y f2f con apt
  apt install -y rofi feh fzf

  #2 instalar LSD (ls con esteroides) desde github release
  echo -e "    [i] Instalando LSD..."
  cd /usr/local/src/
  #buscamos la url del .deb
  lsd_url=$(curl -s https://api.github.com/repos/lsd-rs/lsd/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d : -f 2,3 | tr -d \n | head -n 1)
  wget "$lsd_url" -O lsd.deb
  dpkg -i lsd.deb
  rm lsd.deb

  #instalar BAT (cat con esteroides)
  echo -e "   [i] Instalando BAT..."
  bat_url=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep "browser_download_url.*amd64.deb" | cut -d : -f 2,3 | tr -d \n | head -n 1)
  wget "$bat_url" -O bat.deb
  dpkg -i bat.deb
  rm bat.deb

  echo -e "${greenColour}[+] Herramientas instaladas.${endColour}"


}

# --- LLAMADAS PRINCIPALES ---
install_dependencies
install_dotfiles
install_fonts
install_bspwm_sxhkd
install_polybar
install_picom
