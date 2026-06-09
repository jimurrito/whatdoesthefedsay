/*
  Example config

  services.wdtfs = {
    enable = true;
    # triggers every hour 5:00 - 17:00, M-F
    interval = "0 5-17 * * 1-5";
    keyPath = config.age.secrets.wdtfs_key.path;
  };
*/
{
  description = "(W)hat(D)oes(T)he(F)ed(S)ay script and service";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    test-vm = {
      url = "github:jimurrito/nixos-test-vm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # can not use espresso as it will cause a recursive error for users who use this app via espresso
    qpwsh = {
      url = "git+https://forgejo.immerhouse.com/jimurrito/quiet-powershell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  #
  outputs =
    {
      self,
      nixpkgs,
      test-vm,
      qpwsh,
    }:
    let
      #
      lib = nixpkgs.lib;
      # Supported Architectures
      archs = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # multi arch packager
      packager = sys: {
        ${sys}.default =
          let
            pkgs = import nixpkgs {
              system = sys;
              overlays = [ qpwsh.overlays.default ];
            };
          in
          with lib;
          pkgs.stdenv.mkDerivation {
            pname = "wdtfs";
            meta.mainProgram = "wdtfs";
            version = "0.1.0";
            src = ./.;
            dontBuild = true;
            #
            installPhase = ''
              moduleDir="$out/module"
              mkdir -p "$moduleDir"
              cp getrate.ps1 "$moduleDir/"
              mkdir -p "$out/bin"
              cat > "$out/bin/wdtfs" << EOF
              #!/usr/bin/env bash
              ${getExe pkgs.quietPowershell} -NonInteractive -NoLogo -NoProfile -Command "$moduleDir/getrate.ps1 \$@"
              EOF
              chmod +x "$out/bin/wdtfs"
            '';
          };
      };
      #
    in
    with lib;
    {
      #
      # Builds packages for each arch provided
      # (') is required so foldl will be strict and not lazy
      packages = builtins.foldl' (acc: x: acc // x) { } (map packager archs);
      #
      # Nixpkgs overlay for the package(s)
      overlays.default = final: prev: {
        wdtfs = self.packages.${final.system}.default;
      };
      #
      # Default option to import package into the env
      # and import service options
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          wdtfs-nixops = config.services.wdtfs;
        in
        {
          # Options for services overlay
          options.services.wdtfs = with lib; {
            enable = mkEnableOption "WDTFS scheduled service";
            keyPath = mkOption {
              type = types.str;
              default = "/root/wdtfs-key";
              description = "Path to the Personal Github Access Token to the wdtfs repo";
            };
            interval = mkOption {
              type = types.str;
              default = "daily";
              description = "How often to run wdtfs. Accepts any systemd calendar expression.";
            };
          };
          #
          # config to be implemented via the `options`
          config = lib.mkIf wdtfs-nixops.enable {
            # Imports the overlay to put sonarr-cleanup in pkgs
            nixpkgs.overlays = [ self.overlays.default ];
            # rootless identity
            users = {
              groups.wdtfs = { };
              users.wdtfs = {
                enable = true;
                group = "wdtfs";
                isSystemUser = true;
              };
            };
            # systemd service
            systemd = {
              # systemd service
              services.wdtfs = {
                enable = true;
                description = "(W)hat(D)oes(T)he(F)ed(S)ay service";
                restartIfChanged = true;
                serviceConfig = with lib; {
                  Type = "oneshot";
                  User = "wdtfs";
                  Group = "wdtfs";
                  ExecStart = ''
                    ${getExe pkgs.wdtfs} -TokenPath ${wdtfs-nixops.keyPath}
                  '';
                };
              };
              # timer for service triggering
              timers.wdtfs = {
                enable = true;
                description = "Triggers wdtfs service";
                wantedBy = [ "timers.target" ];
                # triggers every hour 5:00 - 17:00, M-F
                timerConfig.OnCalendar = wdtfs-nixops.interval;
              };
            };
          };
        };
      #
      #
      #
      # TestVM
      nixosConfigurations =
        let
          testConfig =
            { ... }:
            {
              services.wdtfs = {
                enable = true;
                interval = "daily";
                keyPath = "/etc/wdtfs-key";
              };
            };
        in
        {
          test-vm = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
              test-vm.baselineConfig
              # test config
              self.nixosModules.default
              testConfig
            ];
          };
        };

      #
    };
}
