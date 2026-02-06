{
  description = "STM32CubeIDE - Integrated Development Environment for STM32 microcontrollers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        version = "1.19.0";
        buildNumber = "25607";
        tarballName = "st-stm32cubeide_${version}_${buildNumber}_20250703_0907_amd64.tar.gz";

        # The main IDE tarball - must be obtained from STMicroelectronics
        # Download from: https://www.st.com/en/development-tools/stm32cubeide.html
        mainTarball = pkgs.requireFile {
          name = tarballName;
          sha256 = "18fc11e62fc575649956ed9fb477ff4541f25bd2d851d185cafebc9e7f9a9f64";
          message = ''
            STM32CubeIDE ${version} tarball not found in the Nix store.

            This is proprietary software from STMicroelectronics. You must download
            it yourself from the official website:

              https://www.st.com/en/development-tools/stm32cubeide.html

            1. Download the Linux installer: en.st-stm32cubeide_${version}_${buildNumber}_20250703_0907_amd64.sh.zip
            2. Unzip it to get the installer directory
            3. Add the tarball to the Nix store:

               nix-store --add-fixed sha256 ${tarballName}

            Or if you have the file locally:

               nix-prefetch-url file:///path/to/${tarballName}
          '';
        };

        # Runtime dependencies for the various bundled binaries
        runtimeDeps = with pkgs; [
          # Core libraries
          glib
          gtk3
          gdk-pixbuf
          pango
          cairo
          atk
          zlib
          freetype
          fontconfig
          xorg.libX11
          xorg.libXrender
          xorg.libXtst
          xorg.libXi
          xorg.libXext
          xorg.libXrandr
          xorg.libXcursor
          xorg.libXcomposite
          xorg.libXdamage
          xorg.libXfixes
          xorg.libXinerama
          xorg.libXxf86vm
          xorg.libxcb
          xorg.libXau
          xorg.libXdmcp
          xorg.xcbutilimage
          xorg.xcbutilrenderutil
          xorg.xcbutilwm
          xorg.xcbutilkeysyms
          libxkbcommon
          dbus
          dbus-glib

          # Wayland support
          wayland

          # OpenGL
          libGL
          libGLU
          mesa

          # USB support (for debugging probes)
          libusb1
          hidapi

          # Ncurses (mentioned in installer)
          ncurses5

          # For GDB
          stdenv.cc.cc.lib
          expat
          python3

          # SSL/crypto
          openssl

          # Additional libraries
          alsa-lib
          at-spi2-atk
          at-spi2-core
          cups
          udev
          nspr
          nss

          # For CubeProgrammer
          pcsclite
          xercesc
        ];

        stm32cubeide = pkgs.stdenv.mkDerivation rec {
          pname = "stm32cubeide";
          inherit version;

          src = mainTarball;

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
            gnutar
            gzip
          ];

          buildInputs = runtimeDeps;

          dontConfigure = true;
          dontBuild = true;
          dontUnpack = true;

          installPhase = ''
                        runHook preInstall

                        # Extract the main tarball
                        mkdir -p $out/opt/stm32cubeide
                        tar -xzf $src -C $out/opt/stm32cubeide --strip-components=0

                        # Create bin directory
                        mkdir -p $out/bin

                        # Create wrapper script for the main IDE
                        makeWrapper $out/opt/stm32cubeide/stm32cubeide $out/bin/stm32cubeide \
                          --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeDeps}" \
                          --set GDK_BACKEND x11 \
                          --set GTK_THEME "Adwaita"

                        # Also create wayland-compatible wrapper (still uses x11 backend)
                        makeWrapper $out/opt/stm32cubeide/stm32cubeide $out/bin/stm32cubeide_wayland \
                          --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeDeps}" \
                          --set GDK_BACKEND x11 \
                          --set GTK_THEME "Adwaita"

                        # Create wrapper for headless build
                        if [ -f $out/opt/stm32cubeide/headless-build.sh ]; then
                          makeWrapper $out/opt/stm32cubeide/headless-build.sh $out/bin/stm32cubeide-headless \
                            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeDeps}"
                        fi

                        # Desktop file
                        mkdir -p $out/share/applications
                        cat > $out/share/applications/stm32cubeide.desktop << EOF
            [Desktop Entry]
            Name=STM32CubeIDE ${version}
            Comment=Integrated Development Environment for STM32
            GenericName=STM32 IDE
            Exec=$out/bin/stm32cubeide %F
            Icon=$out/opt/stm32cubeide/icon.xpm
            Path=$out/opt/stm32cubeide
            Terminal=false
            StartupNotify=true
            Type=Application
            Categories=Development;IDE;Electronics;
            MimeType=application/x-stm32cubeide;
            EOF

                        # Copy icon
                        mkdir -p $out/share/pixmaps
                        if [ -f $out/opt/stm32cubeide/icon.xpm ]; then
                          cp $out/opt/stm32cubeide/icon.xpm $out/share/pixmaps/stm32cubeide.xpm
                        fi

                        # # Install stlink-server from the separate package
                        # mkdir -p $out/opt/stlink-server
                        # bash $stlinkServerInstaller \
                        #   --noexec --target $out/opt/stlink-server

                        # if [ -f $out/opt/stlink-server/stlink-server ]; then
                        #   chmod +x $out/opt/stlink-server/stlink-server
                        #   makeWrapper $out/opt/stlink-server/stlink-server $out/bin/stlink-server \
                        #     --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.libusb1 ]}"
                        # fi

                        runHook postInstall
          '';

          # autoPatchelfHook settings
          autoPatchelfIgnoreMissingDeps = [
            # These are bundled with the application
            "libjli.so"
            # "libSTLinkUSBDriver.so"
            "libhsmp11.so"
            "libPreparation.so.1"
            # Bundled Qt6 (for CubeProgrammer)
            "libQt6Core.so.6"
            "libQt6DBus.so.6"
            "libQt6Gui.so.6"
            "libQt6Network.so.6"
            "libQt6OpenGL.so.6"
            "libQt6Qml.so.6"
            "libQt6SerialPort.so.6"
            "libQt6Widgets.so.6"
            "libQt6XcbQpa.so.6"
            "libQt6Xml.so.6"
            "libQt6EglFSDeviceIntegration.so.6"
            "libQt6WaylandEglClientHwIntegration.so.6"
            "libQt6WaylandClient.so.6"
            # Bundled Qt4 (for JLink tools)
            "libQtCore.so.4"
            "libQtGui.so.4"
            # Bundled JLink
            "libjlinkarm.so"
            "libjlinkarm.so.8"
            # Optional FFmpeg plugins for JRE (not needed for IDE)
            "libavformat-ffmpeg.so.56"
            "libavcodec-ffmpeg.so.56"
            "libavformat.so.54"
            "libavcodec.so.54"
            "libavformat.so.56"
            "libavcodec.so.56"
            "libavformat.so.57"
            "libavcodec.so.57"
            "libavformat.so.58"
            "libavcodec.so.58"
            "libavformat.so.59"
            "libavcodec.so.59"
            "libavformat.so.60"
            "libavcodec.so.60"
            # xerces versioned lib (we have 3.3, it wants 3.2)
            "libxerces-c-3.2.so"
          ];

          # Set rpath for bundled libraries to find each other
          postFixup = ''
            # Fix the CubeProgrammer tools to find their bundled libs
            CUBEPROG_DIR=$(find $out/opt/stm32cubeide/plugins -type d -name "com.st.stm32cube.ide.mcu.externaltools.cubeprogrammer.linux64_*" | head -1)
            if [ -n "$CUBEPROG_DIR" ]; then
              patchelf --set-rpath "$CUBEPROG_DIR/tools/lib:${pkgs.lib.makeLibraryPath runtimeDeps}" \
                $CUBEPROG_DIR/tools/bin/STM32_Programmer_CLI || true
            fi

            # Fix JLink tools to find their bundled libs
            JLINK_DIR=$(find $out/opt/stm32cubeide/plugins -type d -name "com.st.stm32cube.ide.mcu.externaltools.jlink.linux64_*" | head -1)
            if [ -n "$JLINK_DIR" ]; then
              for bin in $JLINK_DIR/tools/bin/JLink*; do
                if [ -f "$bin" ] && [ -x "$bin" ]; then
                  patchelf --set-rpath "$JLINK_DIR/tools/bin:${pkgs.lib.makeLibraryPath runtimeDeps}" "$bin" || true
                fi
              done
            fi

            # Fix the bundled JRE
            JRE_DIR=$(find $out/opt/stm32cubeide/plugins -type d -name "com.st.stm32cube.ide.jre.linux64_*" | head -1)
            if [ -n "$JRE_DIR" ] && [ -d "$JRE_DIR/jre" ]; then
              for bin in $JRE_DIR/jre/bin/*; do
                if [ -f "$bin" ] && [ -x "$bin" ]; then
                  patchelf --set-rpath "$JRE_DIR/jre/lib:$JRE_DIR/jre/lib/server:${pkgs.lib.makeLibraryPath runtimeDeps}" "$bin" || true
                fi
              done
              for lib in $JRE_DIR/jre/lib/*.so $JRE_DIR/jre/lib/server/*.so; do
                if [ -f "$lib" ]; then
                  patchelf --set-rpath "$JRE_DIR/jre/lib:$JRE_DIR/jre/lib/server:${pkgs.lib.makeLibraryPath runtimeDeps}" "$lib" || true
                fi
              done
            fi
          '';

          meta = with pkgs.lib; {
            description = "Integrated Development Environment for STM32 microcontrollers";
            homepage = "https://www.st.com/en/development-tools/stm32cubeide.html";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
            maintainers = [ ];
            sourceProvenance = [ sourceTypes.binaryNativeCode ];
          };
        };

        # Alternative: FHS-based package for maximum compatibility
        stm32cubeide-fhs = pkgs.buildFHSEnv {
          name = "stm32cubeide";
          targetPkgs = pkgs: runtimeDeps ++ [ stm32cubeide ];
          runScript = "${stm32cubeide}/bin/stm32cubeide";
          meta = stm32cubeide.meta;
        };

      in
      {
        packages = {
          default = stm32cubeide;
          stm32cubeide = stm32cubeide;
          stm32cubeide-fhs = stm32cubeide-fhs;
        };

        # Development shell with all dependencies available
        devShells.default = pkgs.mkShell {
          buildInputs = runtimeDeps ++ [ stm32cubeide ];
          shellHook = ''
            echo "STM32CubeIDE development environment"
            echo "Run 'stm32cubeide' to start the IDE"
          '';
        };
      }
    )
    // {
      # Overlay for use in other flakes
      overlays.default = final: prev: {
        stm32cubeide = self.packages.${prev.system}.default;
      };

      # NixOS module for udev rules (system-independent, outside eachSystem)
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.stm32cubeide;
        in
        {
          options.programs.stm32cubeide = {
            enable = lib.mkEnableOption "STM32CubeIDE and related udev rules";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
              defaultText = lib.literalExpression "stm32cubeide.packages.\${pkgs.stdenv.hostPlatform.system}.default";
              description = "The STM32CubeIDE package to use";
            };

            enableStlink = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable ST-Link udev rules";
            };

            enableJlink = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable SEGGER J-Link udev rules";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

            services.udev.extraRules = lib.concatStringsSep "\n" (
              (lib.optional cfg.enableStlink ''
                # ST-Link V1
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3744", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv1_%n"

                # ST-Link V2
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3748", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv2_%n"

                # ST-Link V2-1
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374b", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv2-1_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3752", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv2-1_%n"

                # ST-Link V3
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374d", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3loader_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374e", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="374f", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3753", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3754", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3755", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3loader_%n"
                SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="3757", MODE="0666", TAG+="uaccess", ENV{ID_MM_DEVICE_IGNORE}="1", SYMLINK+="stlinkv3_%n"
              '')
              ++ (lib.optional cfg.enableJlink ''
                # SEGGER J-Link (old format)
                ATTR{idProduct}=="0101", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idProduct}=="0102", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idProduct}=="0103", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idProduct}=="0104", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idProduct}=="0105", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idProduct}=="0107", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idProduct}=="0108", ATTR{idVendor}=="1366", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"

                # SEGGER J-Link (new format 0x10xx)
                ATTR{idVendor}=="1366", ATTR{idProduct}=="10[0-6][0-9a-f]", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"
                ATTR{idVendor}=="1366", ATTR{idProduct}=="1080", MODE="0666", ENV{ID_MM_DEVICE_IGNORE}="1"

                # SEGGER J-Link HID
                KERNEL=="hidraw*", ATTRS{idVendor}=="1366", MODE="0666"

                # J-Link VCOM ports
                SUBSYSTEM=="tty", ATTRS{idVendor}=="1366", MODE="0666"
              '')
            );
          };
        };
    };
}
