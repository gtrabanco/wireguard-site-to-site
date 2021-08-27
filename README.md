## About this

This is wireguard script configuration for a intermediate public server two interconnect two sites.

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
