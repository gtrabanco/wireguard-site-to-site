
- [About this](#about-this)
- [Warning](#warning)
- [Generate the configuration in your system](#generate-the-configuration-in-your-system)
  - [Linux](#linux)
  - [macOS](#macos)
  - [Windows](#windows)
- [Next step](#next-step)
  - [Starting Wireguard](#starting-wireguard)
  - [Configure terminals](#configure-terminals)
  - [Configure gateways](#configure-gateways)
- [Adding new peers](#adding-new-peers)
- [Using as binaries](#using-as-binaries)
- [Contributing](#contributing)
- [Wireguard Help](#wireguard-help)

## About this

This is wireguard script configuration for a intermediate public server to interconnect two sites.

![Network Schema, there is a LAN called 1 in one side with a router drawing a line to vpn server and another line to internet and the same in the other side](Wireguard-site-to-site.svg)

So you can reach LAN 2 from LAN 1 and vice versa but LAN also reach Internet directly without using VPN Server. The VPN server is only used to reach each LAN.

## Warning

This is not a newbie tool, this is just a helper to configure my VPN server. If you do not know about networking, linux & vpn (wireguard) this tool maybe, it is not for you. Anyway if you know and you think you can do a better job to give a good documentation for everyone I accept contributions.

## Generate the configuration in your system

Install wireguard-tools to generate the configuration.

### Linux

1. Install using whatever package manager is in your Linux system the packages `wireguard` & `wireguard-tools`
2. Configure `.env.dist` and save as `.env`
3. Generate the config

```bash
./generate_wg_config
```

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
./generate_wg_config
```

### Windows

1. Install WSL and use in WSL as Linux


## Next step

### Starting Wireguard

If you have generated the configuration files in the final Wireguard Server you can set up Wireguard as a service by using:

```bash
./start_wg_as_service
```

If you want to test or you want to execute wireguard manually you can by using:

```bash
echo "Starting wireguard"
./start_wg
```

To stop:

```bash
echo "Stoping wireguard"
./stop_wg
```

### Configure terminals

Install wireguard in the terminals (phone or computer) that would be also a peers (outside of the LANS) and use the configuration files for those peers.

### Configure gateways

In the LANs, install the wireguard or use wireguard-go dockerized using the configuration file.

If you use Wg in your gateway it must know how to get any direct local network so you should be able to get those networks that router must know how to reach and route to other networks through the VPN networks. Any special routing configuration can be needed so you need some networking knowledge.

Please do not use issues to ask about any other configuration that is not implicit with wireguard or any linux server configuration.

## Adding new peers

After generating a configuration you can add a new peer by using `./add_new_peer` command.

See usage with `./add_new_peer --help`.

**IMPORTANT**: You need to know the ip you will give to the peer and configuration must be as when generated (minimum the public & private keys & configuration for server, normmally called `wg0`).

## Using as binaries

You can use these scripts by adding them to `PATH` in your `.bashrc` (or equivalent file), execute in the path of these files locally:

```bash
echo "PATH=\"\${PATH+:\$PATH:$PWD}\"\n" | tee -a ~/.bashrc &>/dev/null
. ~/.bashrc
{ grep -q "$PWD" ~/.bashrc && command -v add_new_peer && echo "Now you can execute wireguard-site-to-site scripts"; } || echo "[FAIL] wireguard-site-to-site PATH could not be found"

```

## Contributing

PRs are accepted to improve the scripts, tools and documentation. Anyway, whatever contribution should keep the main target which is connect P2P two or more LANs.

## Wireguard Help

If you need some help with wireguard the [official webiste](https://www.wireguard.com/) ([witepapper](https://www.wireguard.com/papers/wireguard.pdf)) is very good reference but you can also access to sample wireguard configurations and documentation here:
- https://github.com/pirate/wireguard-docs
