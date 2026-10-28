{
  description = "Bifrost 2.3.2 OCI image, built from pinned source with Nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    bifrost-src = {
      url = "github:maximhq/bifrost/a05ea20e68bf116a35e9f05b1a3d749624b3935e";
      flake = false;
    };
  };
  outputs = { nixpkgs, bifrost-src, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      staticPkgs = pkgs.pkgsStatic;
      lib = pkgs.lib;
      version = "2.3.2";
      revision = "a05ea20e68bf116a35e9f05b1a3d749624b3935e";
      # Keep the upstream commit pinned while applying dependency security fixes.
      uiSource = pkgs.applyPatches {
        name = "bifrost-ui-security-updates";
        src = "${bifrost-src}/ui";
        patches = [ ./patches/ui-security-updates.patch ];
      };
      transportSource = pkgs.applyPatches {
        name = "bifrost-transport-security-updates";
        src = "${bifrost-src}/transports";
        patches = [ ./patches/transport-security-updates.patch ];
      };
      ui = pkgs.buildNpmPackage {
        pname = "bifrost-ui";
        inherit version;
        src = uiSource;
        nodejs = pkgs.nodejs_24;
        npmDepsHash = "sha256-QveIkqdisBha6fTQkuZm0PFlg8GYJMgyRaEKS4gVvCo=";
        npmBuildScript = "build-enterprise";
        installPhase = ''
          mkdir -p "$out"
          cp -R out/. "$out/"
        '';
      };
      # The transports module requires Go 1.27.3.
      bifrost = staticPkgs.buildGoLatestModule {
        pname = "bifrost";
        inherit version;
        src = transportSource;
        subPackages = [ "bifrost-http" ];
        vendorHash = "sha256-CkBA+2NijJih32Sewz8cRDdiflykBhuda9V5tgD7s9I=";
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
