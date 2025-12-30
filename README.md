# STM32CubeIDE for NixOS

This Nix flake provides STM32CubeIDE 2.0.0 packaged for NixOS.

## Prerequisites

STM32CubeIDE is proprietary software from STMicroelectronics. You must download
the installer yourself and add the tarball to the Nix store before building.

### Step 1: Download the installer

1. Go to https://www.st.com/en/development-tools/stm32cubeide.html
2. Download the Linux installer: `en.st-stm32cubeide_2.0.0_26820_20251114_1348_amd64.sh.zip`
3. Unzip it to get the installer `.sh` file

### Step 2: Extract the required files

The downloaded `.sh` file is a self-extracting archive. Extract it to get the required files:

```bash
bash st-stm32cubeide_2.0.0_26820_20251114_1348_amd64.sh --noexec --target /tmp/stm32cubeide-extract
```

This will extract the contents to `/tmp/stm32cubeide-extract/`, which includes:
- `st-stm32cubeide_2.0.0_26820_20251114_1348_amd64.tar.gz` - The main IDE tarball
- `st-stlink-server.2.1.1-1-linux-amd64.install.sh` - The ST-Link Server installer

### Step 3: Add the files to the Nix store

Add both required files to the Nix store:

```bash
# Add the main IDE tarball
nix-store --add-fixed sha256 /tmp/stm32cubeide-extract/st-stm32cubeide_2.0.0_26820_20251114_1348_amd64.tar.gz

# Add the ST-Link Server installer
nix-store --add-fixed sha256 /tmp/stm32cubeide-extract/st-stlink-server.2.1.1-1-linux-amd64.install.sh
```

Each command will output a store path like:
```
/nix/store/...-st-stm32cubeide_2.0.0_26820_20251114_1348_amd64.tar.gz
/nix/store/...-st-stlink-server.2.1.1-1-linux-amd64.install.sh
```

## Quick Start

### Build the package

```bash
nix build .#stm32cubeide
```

### Run directly

```bash
nix run .#stm32cubeide
```

### Install in your profile

```bash
nix profile install .#stm32cubeide
```

## Use in a NixOS configuration

Add this flake as an input to your system flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stm32cubeide.url = "path:/path/to/this/flake";
  };

  outputs = { self, nixpkgs, stm32cubeide, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the NixOS module (enables udev rules and installs the package)
        stm32cubeide.nixosModules.default

        # Your other configuration
        ({ ... }: {
          programs.stm32cubeide = {
            enable = true;
            # Optional: disable J-Link rules if you don't use SEGGER probes
            # enableJlink = false;
          };
        })
      ];
    };
  };
}
```

### Use via overlay

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    stm32cubeide.url = "path:/path/to/this/flake";
  };

  outputs = { self, nixpkgs, stm32cubeide, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ stm32cubeide.overlays.default ];
          environment.systemPackages = [ pkgs.stm32cubeide ];
        })
      ];
    };
  };
}
```

## Available Packages

- `stm32cubeide` (default): The main IDE package with autoPatchelf
- `stm32cubeide-fhs`: FHS-based package for maximum compatibility (uses buildFHSEnv)

## What's Included

This package includes all components bundled with STM32CubeIDE:

- **STM32CubeIDE** (Eclipse-based IDE)
- **Bundled OpenJDK JRE** (Temurin 21.0.8)
- **ARM GNU Toolchain** (arm-none-eabi-gcc 13.3.1, arm-none-eabi-gdb, etc.)
- **STM32CubeProgrammer CLI**
- **OpenOCD for STM32** (0.12.0+dev)
- **SEGGER J-Link tools**
- **ST-Link Server** (2.1.1)
- **GNU Make**

## Binaries Provided

After installation, the following commands are available:

- `stm32cubeide` - Main IDE
- `stm32cubeide_wayland` - IDE with X11 backend (for Wayland compatibility)
- `stm32cubeide-headless` - Headless build tool
- `stlink-server` - ST-Link debugging server

## udev Rules

The NixOS module automatically installs udev rules for:

### ST-Link Debuggers
- ST-Link V1 (STM32VL Discovery)
- ST-Link V2 (STM32L/F4 Discovery)
- ST-Link V2-1 (Nucleo boards)
- ST-Link V3 (standalone and embedded)

### SEGGER J-Link Debuggers
- All J-Link product variants (old and new USB IDs)
- J-Link HID interfaces
- J-Link VCOM ports

## Module Options

```nix
programs.stm32cubeide = {
  enable = true;              # Enable STM32CubeIDE
  package = <package>;        # Override the package (defaults to this flake's package)
  enableStlink = true;        # Enable ST-Link udev rules (default: true)
  enableJlink = true;         # Enable J-Link udev rules (default: true)
};
```

## Troubleshooting

### "file not found in the Nix store" error

Make sure you've added both required files to the Nix store:

```bash
# Add the main IDE tarball
nix-store --add-fixed sha256 /path/to/st-stm32cubeide_2.0.0_26820_20251114_1348_amd64.tar.gz

# Add the ST-Link Server installer
nix-store --add-fixed sha256 /path/to/st-stlink-server.2.1.1-1-linux-amd64.install.sh
```

See the Prerequisites section for detailed instructions on extracting these files from the STM32CubeIDE installer.

### IDE doesn't start

Try the FHS-based package which provides better compatibility:

```bash
nix run .#stm32cubeide-fhs
```

### USB debugging probes not detected

1. Make sure you have the NixOS module enabled with udev rules
2. Reload udev rules: `sudo udevadm control --reload-rules && sudo udevadm trigger`
3. Reconnect your debugging probe

### Graphics issues

The package forces X11 backend (`GDK_BACKEND=x11`) for maximum compatibility on Wayland systems.

## License

STM32CubeIDE is proprietary software by STMicroelectronics. This Nix packaging is provided for convenience and does not grant any additional rights to the software.

By using this package, you agree to the STMicroelectronics Software License Agreement (SLA0048).
