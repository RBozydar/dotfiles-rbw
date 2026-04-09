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

### Codex sandbox / bubblewrap
Managed in `ansible-playbooks/tasks/codex-sandbox.yml`.

Manual equivalent:
```
sudo apt update
sudo apt install apparmor apparmor-profiles
sudo cp ~/repo/dotfiles/misc/etc/sysctl.d/99-codex-sandbox.conf /etc/sysctl.d/99-codex-sandbox.conf
sudo sysctl -p /etc/sysctl.d/99-codex-sandbox.conf
sudo cp /usr/share/apparmor/extra-profiles/bwrap-userns-restrict /etc/apparmor.d/
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
sudo systemctl reload apparmor
```
