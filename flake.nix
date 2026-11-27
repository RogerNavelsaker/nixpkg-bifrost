{
  description = "Bifrost 2.7.0 OCI image, built from pinned source with Nix";
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://rogernavelsaker.cachix.org"
      "https://nacosolutions.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "rogernavelsaker.cachix.org-1:n1DtzMNhA9Rz4Kg3xlXOi/KceULu8VrMbs9WXyMFQNQ="
      "nacosolutions.cachix.org-1:JzCiW2CLcuLXtwOVAg3SlSK/kpqWbfSFEVenyKVUlug="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bifrost-src = {
      url = "github:maximhq/bifrost/d979e72f205e5ae445002af5cd60d37ee09d22da";
      flake = false;
    };
  };
  outputs = { nixpkgs, bifrost-src, ... }:
    let
      system = "x86_64-linux";
      goVersion = "1.27.4";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            # nixpkgs ships Go 1.27.3; upstream transports/go.mod requires 1.27.4.
            go_1_27 = prev.go_1_27.overrideAttrs (_: {
              version = goVersion;
              src = prev.fetchurl {
                url = "https://go.dev/dl/go1.27.4.src.tar.gz";
                hash = "sha256-c8+4VxrsDAEXdofbhxY9Rqog6XeWcncokaoXZU2aYJk=";
              };
            });
          })
        ];
      };
      staticPkgs = pkgs.pkgsStatic;
      lib = pkgs.lib;
      version = "2.7.0";
      revision = "d979e72f205e5ae445002af5cd60d37ee09d22da";
      ui = pkgs.buildNpmPackage {
        pname = "bifrost-ui";
        inherit version;
        src = "${bifrost-src}/ui";
        nodejs = pkgs.nodejs_24;
        npmDepsHash = "sha256-JtaSXBfz7toZ8gF9Jjq5iveV/b5obQNhA9VvjyvDky0=";
        npmBuildScript = "build-enterprise";
        env.NODE_OPTIONS = "--max-old-space-size=8192";
        installPhase = ''
          mkdir -p "$out"
          cp -R out/. "$out/"
        '';
      };
      # The transports module requires Go 1.27.4 (overlay above).
      bifrost = staticPkgs.buildGoLatestModule {
        pname = "bifrost";
        inherit version;
        src = "${bifrost-src}/transports";
        subPackages = [ "bifrost-http" ];
        vendorHash = "sha256-OcyxjGlIHaOsQYzAwhPOEb5TWl+wfIk7DWDbE2Y/OrU=";
        tags = [ "sqlite_static" ];
        ldflags = [ "-s" "-w" "-X" "main.Version=v${version}" "-extldflags=-static" ];
        trimpath = true;
        doCheck = false;
        preBuild = ''
          mkdir -p bifrost-http/ui
          cp -R ${ui}/. bifrost-http/ui/
        '';
      };
      entrypoint = pkgs.writeTextFile {
        name = "bifrost-entrypoint";
        destination = "/bin/bifrost-entrypoint";
        executable = true;
        text = ''
          #!${pkgs.dash}/bin/dash
          set -eu
          exec ${bifrost}/bin/bifrost-http -app-dir "''${APP_DIR:-/data}" -port "''${APP_PORT:-8080}" -host "''${APP_HOST:-0.0.0.0}" -log-level "''${LOG_LEVEL:-info}" -log-style "''${LOG_STYLE:-json}" "$@"
        '';
      };
      licenses = pkgs.runCommand "bifrost-licenses" { } ''
        mkdir -p "$out/share/licenses/bifrost"
        cp ${bifrost-src}/LICENSE "$out/share/licenses/bifrost/LICENSE"
        cp ${bifrost-src}/THIRD_PARTY_NOTICES.md "$out/share/licenses/bifrost/THIRD_PARTY_NOTICES.md"
      '';
      image = pkgs.dockerTools.buildLayeredImage {
        name = "bifrost";
        tag = "v${version}";
        created = "1970-01-01T00:00:01Z";
        contents = [
          entrypoint
          pkgs.cacert
          (pkgs.dockerTools.fakeNss.override {
            extraPasswdLines = [ "bifrost:x:10001:10001:Bifrost:/data:/nonexistent" ];
            extraGroupLines = [ "bifrost:x:10001:" ];
          })
          licenses
          pkgs.tzdata
        ];
        fakeRootCommands = ''
          mkdir -p ./data
          chown 10001:10001 ./data
          chmod 0750 ./data
          mkdir -p ./usr/share/licenses
          ln -s ${licenses}/share/licenses/bifrost ./usr/share/licenses/bifrost
        '';
        config = {
          User = "10001:10001";
          WorkingDir = "/data";
          Entrypoint = [ "${entrypoint}/bin/bifrost-entrypoint" ];
          Cmd = [ ];
          Env = [ "APP_DIR=/data" "APP_PORT=8080" "APP_HOST=0.0.0.0" "LOG_LEVEL=info" "LOG_STYLE=json" "HOME=/data" ];
          ExposedPorts = { "8080/tcp" = { }; };
          Volumes = { "/data" = { }; };
          StopSignal = "SIGTERM";
          Labels = {
            "org.opencontainers.image.source" = "https://github.com/RogerNavelsaker/nixpkg-bifrost";
            "org.opencontainers.image.version" = version;
            "org.opencontainers.image.revision" = revision;
            "org.opencontainers.image.licenses" = "Apache-2.0";
          };
        };
      };
    in {
      packages.${system} = { default = image; inherit bifrost image ui; };
      checks.${system} = { inherit bifrost image; };
    };
}
