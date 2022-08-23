Manual commands

```
sudo cp ~/.config/wallpapers/webb_nebula_2560.png /usr/share/pixmap
sudo cp ~/repo/dotfiles/misc/etc/lightdm/lightdm-gtk-greeter.conf /etc/lightdm/lightdm-gtk-greeter.conf
```

### AIO - Liquid CTL
Copy [liquidctl rules](https://github.com/liquidctl/liquidctl/blob/main/extra/linux/71-liquidctl.rules)
to ```/etc/udev/rules.d/71-liquidctl.rules```

Add systemd service
```
[Unit]
Description=AIO startup service

[Service]
Type=oneshot
ExecStart=liquidctl initialize all

[Install]
WantedBy=default.target
```

execute this
```
# systemctl daemon-reload
# systemctl start liquidcfg
# systemctl enable liquidcfg
```

Fix timezone with Windows
```
timedatectl set-local-rtc 1 --adjust-system-clock
```

fstab
u300318@u300318.your-storagebox.de:/home /mnt/hetzner fuse.sshfs noauto,x-systemd.automount,_netdev,users,IdentityFile=/home/rbw/.ssh/borg,allow_other,reconnect 0 0