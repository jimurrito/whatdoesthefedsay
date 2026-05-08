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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    test-vm.url = "github:jimurrito/nixos-test-vm";
  };
  #
  outputs =
    {
      self,
      nixpkgs,
      test-vm,
    }:
    let
      # Inject powershell.config.json into $PSHOME
      # Without this, powershell is verbose log a bunch of random crap when used in a systemd service.
      quietPowershell = pkgs.powershell.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          echo '{"LogLevel":"Critical"}' > $out/share/powershell/powershell.config.json
        '';
      });
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
    in
    with lib;
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
          ${getExe quietPowershell} -NonInteractive -Command "$moduleDir/getrate.ps1 \$@"
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
                path = [
                  quietPowershell
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
