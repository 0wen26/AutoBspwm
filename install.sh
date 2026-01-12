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

function ctrl_c(){
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
function install_dependencies(){
  echo -e "\n${yellowColour}[*] Comprobando distribución y dependencias... ${endColour}\n"
  # Leemos el nombre de la distribución ( el ID, que suele ser 'debian', 'kali', 'parrot')
  # Usamos 'grep' para sacar la línea y 'cut' para quedarnos con el nombre limpio.
  #
  if grep -iq "Parrot" /etc/os-release; then
    echo -e "   [i] Distribución detectada: ${purpleColour}Parrot OS${endColour}"
    echo -e "   [i] Modo precavido activado: Solo actualizaremos listas (apt update)."
    apt update
  else
    echo -e "   [i] Distribución detectada: ${blueColour}Linux Genérico (Debian,Ubuntu,Kali)${endColour}"
    echo -e "   [i] Actualizando listas de paquetes..."
    apt update
  fi
  #Instalamos las herramientas básicas de compilación y las librerias gráficas XCB
  # - build-essential: Trae el compilador 'gcc' y 'make'
  # - libxcb-*: Son las piezas de lego para manejar ventanas
  apt install -y build-essential git vim xcb libxcb-util0-dev libxcb-ewmh-dev libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-xinerama0-dev libasound2-dev libxcb-xtest0-dev libxcb-shape0-dev
}

# --- FUNCIÓN INSTALAR DOTFILES (CONFIGURACIÓN) ---
#
function install_dotfiles(){
  echo -e "\n${turquoiseColour}[*] Copiando archivos de configuración (Dotfiles)...${endColour}\n"
  
  # Verificamos que se esté ejecutando con sudo para poder detectar al usuario real
  if [ -z "$SUDO_USER" ]; then
    echo -e "${redColour}[!] Error: No se detectó el usuario real. ¿Ejecustaste con sudo?${endColour}"
    exit -1
  fi
  
  # Definimos la ruta real del usuario
  real_user_home="/home/$SUDO_USER"
  config_src="$(dirname "$0")/config" #ruta donde estan tus carpetas copiadas


  #entramos a la carpeta origen
  cd "$config_src" || exit 1

  # 1. COPIA PARA EL USUARIO NORMAL
  #
  echo -e "   [i] Copiando configuraciones para el usuario: ${purpleColour}$SUDO_USER${endColour}"

  # Creamos la carpeta .config si no existe ( mkdir -p no da error si ya existe)
  mkdir -p "$real_user_home/.config"


  # Copiamos todo recursivamente (-r) a la carpeta .config del usuario
  # Usamos 'cp -r *' para copiar todas las carpetas que tengas ahí
  cp -r * "$real_user_home/.config/"

  # -- PASO CRÍTICO: ARREGLAR PERMISOS ---
  #  Al copiar siendo root, los archivos ahora pertenecen a root.
  #  El usuario no podría editar sus propios archivos. ¡Hay que devolvérselos!

  chown -R "$SUDO_USER:$SUDO_USER" "$real_user_home/.config"

  # ---------------------------------------------------------
  # 2. COPIA PARA EL USUARIO ROOT
  # ---------------------------------------------------------
  #
  echo -e "   [i] Copiando configuraciones para el usuario ${redColour}root${endColour}"
  
  mkdir -p /root/.config

  # Copiamos todo también al home de root
  cp -r * /root/.config


  echo -e "${greenColour}[+] Configuraciones copiadas correctamente (user + root) y permisos corregidos.${endColour}"

}

# --- FUNCIÓN INSTALAR FUENTES ---
#
function install_fonts(){
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

function install_bspwm_sxhkd(){
  echo -e "\n${blueColour}[*] Instalando BSPWM y SXHKD...${endColour}\n"

  # Nos movemos a una carpeta de fuentes del sistema
  cd /usr/local/src

  # 1. Instalamos bspwm
  if [ ! -d "bspwm"]; then # Si la carpeta no existe, clonamos
    git clone https://github.com/baskerville/bspwm.git
  fi

  cd bspwm
  make
  make install

  # Volvemos atrás
  cd ..

  # 2. Instalamos sxhkd
  if [ ! -d "sxhkd"]; then
    git clone https://github.com/baskerville/sxhkd.git
  fi
  
  cd sxhkd
  make
  make install

  # Volvemos al directorio original del usuario
  cd ~

  echo -e "\n${greenColour}[+] BSPWM y SXHKD instalados correctamente.${endColour}"

}

# --- FUNCIÓN INSTALAR NEOVIM (LATEST RELEASE) ---
#
function install_neovim(){
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


# --- LLAMADAS PRINCIPALES ---
install_dependencies
install_dotfiles
install_fonts
install_bspwm_sxhkd



