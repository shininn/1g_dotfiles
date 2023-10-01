#!/bin/bash

clear

# Nice terminal colors
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
WARN="$(tput setaf 166)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
ORANGE=$(tput setaf 166)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# Set the script to exit on error
set -e

# Function that install package
install_package() {
  echo "$1"
  # Checking if package is already installed
  if yay -Q "$1" &>> /dev/null ; then
    echo -e "${OK} $1 is already installed. Skipping..."
  else
    # Package not installed
    echo -e "${NOTE} Installing $1 ..."
    yay -S --noconfirm "$1"
    # Making sure package is installed
    if yay -Q "$1" &>> /dev/null ; then
      echo -e "\e[1A\e[K${OK} $1 was installed."
    else
      # Something is missing, exiting to review log
      echo -e "\e[1A\e[K${ERROR} $1 failed to install. You may need to install manually!"
      exit 1
    fi
  fi
}

all_pkg_names=(
  hypr
  development
  entertainment
  media
  must_have
  useful
)

# Install all packages
install_all_packages() {
  for PKGTYPE in "${all_pkg_names[@]}"; do
    printf "\n%s - Installing ${PKGTYPE} packages... \n" "${NOTE}"

    for PKG1 in $(cat ./packages/${PKGTYPE}.list)
    do
      install_package "$PKG1"
      if [ $? -ne 0 ]; then
        echo -e "\e[1A\e[K${ERROR} - $PKG1 install had failed"
        exit 1
      fi
    done
  done
}

nvidia_pkg=(
  nvidia-dkms
  nvidia-settings
  nvidia-utils
  libva
  libva-nvidia-driver-git
)

install_nvidia() {
  echo "Are you using NVIDIA GPU? (y/n)"
  read -r nvidia
  if [[ "$nvidia" == "y" ]]; then
    printf "${YELLOW}Installing Nvidia Hyprland...${RESET}\n"
    if pacman -Qs hyprland > /dev/null; then
      read -n1 -rp "${CAT} Hyprland detected. Would you like to remove and install hyprland-nvidia instead? (y/n) " nvidia_hypr
      echo
      if [[ $nvidia_hypr =~ ^[Yy]$ ]]; then
        for hyprnvi in hyprland hyprland-nvidia hyprland-nvidia-hidpi-git; do
          sudo pacman -R --noconfirm "$hyprnvi" 2>/dev/null | tee -a "$LOG" || true
        done
      fi
    fi

    # install hyprland-nvidia-git
    install_package "hyprland-nvidia-git" 2>&1 | tee -a "$LOG"

    # Install additional Nvidia packages
    printf "${YELLOW} Installing Nvidia packages...\n"
    for krnl in $(cat /usr/lib/modules/*/pkgbase); do
      for NVIDIA in "${krnl}-headers" "${nvidia_pkg[@]}"; do
        install_package "$NVIDIA" 2>&1 | tee -a "$LOG"
      done
    done

    # Check if the Nvidia modules are already added in mkinitcpio.conf and add if not
    if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
      echo "Nvidia modules already included in /etc/mkinitcpio.conf" 2>&1 | tee -a "$LOG"
    else
      sudo sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf 2>&1 | tee -a "$LOG"
      echo "Nvidia modules added in /etc/mkinitcpio.conf"
    fi

    sudo mkinitcpio -P 2>&1 | tee -a "$LOG"
    printf "\n"
    printf "\n"
    printf "\n"

    # Additional Nvidia steps
    NVEA="/etc/modprobe.d/nvidia.conf"
    if [ -f "$NVEA" ]; then
      printf "${OK} Seems like nvidia-drm modeset=1 is already added in your system..moving on.\n"
      printf "\n"
    else
      printf "\n"
      printf "${YELLOW} Adding options to $NVEA..."
      sudo echo -e "options nvidia-drm modeset=1" | sudo tee -a /etc/modprobe.d/nvidia.conf 2>&1 | tee -a "$LOG"
      printf "\n"
    fi

    # additional for GRUB users
    # Check if /etc/default/grub exists
    if [ -f /etc/default/grub ]; then
      # Check if nvidia_drm.modeset=1 is already present
      if ! sudo grep -q "nvidia_drm.modeset=1" /etc/default/grub; then
        # Add nvidia_drm.modeset=1 to GRUB_CMDLINE_LINUX_DEFAULT
        sudo sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"/\1 nvidia_drm.modeset=1"/' /etc/default/grub
        # Regenerate GRUB configuration
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo "nvidia_drm.modeset=1 added to /etc/default/grub"
      else
        echo "nvidia_drm.modeset=1 is already present in /etc/default/grub"
      fi
    else
      echo "/etc/default/grub does not exist"
    fi

    # Blacklist nouveau
    read -n1 -rep "${CAT} Would you like to blacklist nouveau? (y/n)" response
    echo
    if [[ $response =~ ^[Yy]$ ]]; then
      NOUVEAU="/etc/modprobe.d/nouveau.conf"
      if [ -f "$NOUVEAU" ]; then
        printf "${OK} Seems like nouveau is already blacklisted..moving on.\n"
      else
        printf "\n"
        echo "blacklist nouveau" | sudo tee -a "$NOUVEAU" 2>&1 | tee -a "$LOG"
        printf "${NOTE} has been added to $NOUVEAU.\n"
        printf "\n"

        # To completely blacklist nouveau (See wiki.archlinux.org/title/Kernel_module#Blacklisting 6.1)
        if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
          echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf" 2>&1 | tee -a "$LOG"
        else
          echo "install nouveau /bin/true" | sudo tee "/etc/modprobe.d/blacklist.conf" 2>&1 | tee -a "$LOG"
        fi
      fi
    else
      printf "${NOTE} Skipping nouveau blacklisting.\n"
    fi
  fi
}

# Install nerd fonts
install_nerd_font() {
  printf "\n%s - Installing Nerd Fonts... \n" "${NOTE}"

  mkdir -p $HOME/Downloads/nerdfonts/
  cd $HOME/Downloads/
  wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.1/CascadiaCode.zip
  unzip '*.zip' -d $HOME/Downloads/nerdfonts/
  rm -rf *.zip
  sudo cp -R $HOME/Downloads/nerdfonts/ /usr/share/fonts/
}

# Install gtk-xfce theme icons
install_gtk_theme_and_icons() {
  printf "\n%s - Installing GTK Theme and Icons... \n" "${NOTE}"

  cd $HOME/Downloads/
  git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git

  # installs theme
  sudo cp -r Tokyo-Night-GTK-Theme/themes/Tokyonight-Dark-BL-LB /usr/share/themes/

  # installs icons
  sudo cp -r Tokyo-Night-GTK-Theme/icons/Tokyonight-Dark /usr/share/icons/

  # deletes folder
  rm -r Tokyo-Night-GTK-Theme/
}

# Stow Dotfiles
stow_dotfiles() {
  printf "\n%s - Copying config with stow... \n" "${NOTE}"

  cd dotfiles/
  stow */ --target=$HOME/
}

# Setup zsh with zap
setup_zsh() {
  # set zsh as default shell
  chsh -s $(which zsh)

  # install zap
  zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh)
}

install_all_packages
install_nvidia
install_nerd_font
install_gtk_theme_and_icons
stow_dotfiles
setup_zsh
