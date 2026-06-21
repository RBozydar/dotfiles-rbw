# Ansible Playbooks

These playbooks default to a terminal/server-oriented setup. GUI packages,
desktop config, and NVIDIA-specific tooling are opt-in.

Run the default local bootstrap from this directory:

```sh
ansible-playbook main.yml
```

Run the workstation profile when the machine should get GUI apps/config and the
NVIDIA development stack:

```sh
ansible-playbook main.yml --extra-vars "@vars/workstation.yml"
```

The workstation vars currently enable:

- `enable_gui`
- `enable_nvidia`

Run a work Mac profile when the machine should get GUI apps/config but no
personal apps:

```sh
ansible-playbook main.yml --extra-vars "@vars/macos-work.yml"
```

Run a private Mac profile when the machine should also get personal GUI apps:

```sh
ansible-playbook main.yml --extra-vars "@vars/macos-private.yml"
```

The private Mac profile adds apps such as Home Assistant, IINA, Moonlight,
Proton VPN, Spotify, Transmission, WhatsApp, and WiFiman.

macOS container tooling uses Colima plus the Docker CLI packages. Docker Desktop
is intentionally not managed.

macOS defaults are applied by `files/macos/defaults.sh` when
`configure_macos_defaults` is true. The script contains one commented setting per
command so machine preferences can be reviewed before running. Disable this pass
with `-e configure_macos_defaults=false`.

You can also pass either flag directly for one-off runs:

```sh
ansible-playbook main.yml -e enable_gui=true -e enable_nvidia=false -e enable_private_apps=false
```

The main play targets `localhost`, so inventory `host_vars` are not used for
the normal local bootstrap path.
