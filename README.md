# What Does the Fed(eral Reserve) Say?

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell)
![Nix](https://img.shields.io/badge/Nix-Flake-5277C3?logo=nixos)
![License](https://img.shields.io/badge/License-GPL%20v3-blue)

A PowerShell script that scrapes the Federal Reserve's H.15 release page for the current effective federal funds rate and commits it as JSON to a GitHub Pages wite. Packaged as a NixOS module with a built-in systemd timer for scheduled execution.

## Table of Contents

- [Requirements](#requirements)
- [Usage](#usage)
  - [PowerShell](#powershell)
  - [Nix Flake](#nix-flake)
- [Nix Module Options](#nix-module-options)
- [License](#license)

## Requirements

- PowerShell 5.1 or later
- A GitHub Personal Access Token (PAT) with **Contents** read/write permission on the target repository, stored in a plain-text file

## Usage

### PowerShell

Run the script directly, providing the path to your token file:

```powershell
.\getrate.ps1 -TokenPath "<path-to-token-file>"
```

To write the rate data to a custom path within the repository:

```powershell
.\getrate.ps1 -TokenPath "<path-to-token-file>" -Path "<repo-relative-file-path>"
```

**Real examples:**

```powershell
# Fetch the latest Fed rate and commit it to the default 'rate.html' on main
.\getrate.ps1 -TokenPath "C:\secrets\github_token.txt"

# Same, but commit to a custom path
.\getrate.ps1 -TokenPath "C:\secrets\github_token.txt" -Path "data/rate.json"
```

### Nix Flake

Add the flake as an input, then wire the NixOS module into your configuration:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-<version>";
    whatdoesthefedsay = {
      url = "github:jimurrito/whatdoesthefedsay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, whatdoesthefedsay, ... }: {
    nixosConfigurations."<hostname>" = nixpkgs.lib.nixosSystem {
      system = "<arch>";
      modules = [
        whatdoesthefedsay.nixosModules.default
        {
          services.wdtfs = {
            enable = true;
            interval = "<systemd-calendar-expression>";
            keyPath = "<path-to-token-file>";
          };
        }
      ];
    };
  };
}
```

**Real example:**

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    whatdoesthefedsay = {
      url = "github:jimurrito/whatdoesthefedsay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, whatdoesthefedsay, ... }: {
    nixosConfigurations."myhost" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        whatdoesthefedsay.nixosModules.default
        {
          services.wdtfs = {
            enable = true;
            # triggers every hour 5:00 - 17:00, M-F
            interval = "0 5-17 * * 1-5";
            keyPath = config.age.secrets.wdtfs_key.path;
          };
        }
      ];
    };
  };
}
```

## Nix Module Options

| Option | Type | Default | Description |
|---|---|---|---|
| `services.wdtfs.enable` | bool | `false` | Enable the WDTFS scheduled service |
| `services.wdtfs.keyPath` | string | `"/root/wdtfs-key"` | Path to a plain-text file containing the GitHub PAT |
| `services.wdtfs.interval` | string | `"daily"` | How often to run. Accepts any systemd calendar expression |

## License

This project is licensed under the [GNU General Public License v3](LICENSE.md).
