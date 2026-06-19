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

You can also pass either flag directly for one-off runs:

```sh
ansible-playbook main.yml -e enable_gui=true -e enable_nvidia=false
```

The main play targets `localhost`, so inventory `host_vars` are not used for
the normal local bootstrap path.
