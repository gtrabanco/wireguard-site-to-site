## About this

This is wireguard script configuration for a intermediate public server to interconnect two sites.

LAN 1 --- LAN 1 Router ---- Server (in Internet, like VPS) ---- LAN 2 Router --- LAN 2

So you can reach LAN 2 from LAN 1 and vice versa.

## Generate the configuration in your system

Install wireguard-tools to generate the configuration.

### macOS

1. Install brew & wireguard cli

```bash
! { command -v brew &> /dev/null; } && /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
! brew list wireguard-tools &> /dev/null && brew install wireguard-go wireguard-tools
```

2. Configure `.env.dist` and rename to `.env`

```bash
mv .env.dist .env
```

3. Generate the config

```bash
./generate_config.sh
```
