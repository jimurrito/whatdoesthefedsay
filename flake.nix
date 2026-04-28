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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  #
  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
    in
    {
      packages.${system}.default = pkgs.stdenv.mkDerivation {
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
          ${lib.getExe pkgs.powershell} -NonInteractive -Command "$moduleDir/getrate.ps1 \$@"
          EOF
          chmod +x "$out/bin/wdtfs"
        '';
      };

      #
      #
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          pkgsystem = pkgs.stdenv.hostPlatform.system;
          mainpackage = self.packages.${pkgsystem}.default;
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
            # Imports package and runs the install steps
            environment.systemPackages = [
              mainpackage
            ];
            # rootless identity
            # Requires home dir as this needs an interactive shell
            # If we can port `ionmod` module to a derivation, this can go back to `isSystemUser = true;`
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
                path = with pkgs; [
                  powershell
                ];
                serviceConfig = with lib; {
                  Type = "oneshot";
                  User = "wdtfs";
                  Group = "wdtfs";
                  ExecStart = ''
                    ${getExe mainpackage} -TokenPath ${wdtfs-nixops.keyPath}
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
    };
}
