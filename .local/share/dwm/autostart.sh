#!/bin/sh

#setxkbmap -option altwin:swap_lalt_lwin
refkb

feh --bg-fill ~/Documents/wallpaper.png
#feh --randomize --bg-fill ~/Documents/wallpapers/*

#gsettings set org.freedesktop.ibus.panel xkb-icon-rgba '#fdaefd'

# Background apps
picom &
nm-applet &
blueman-applet &
volumeicon &
keepassxc &
megasync &
dwmblocks &
#flatpak run dev.vencord.Vesktop &
