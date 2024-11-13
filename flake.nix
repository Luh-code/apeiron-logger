{
  description = "A simple Nix flake to compile a Zig program";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          apeiron-core = pkgs.stdenv.mkDerivation {
            pname = "apeiron";
            version = "0.1.0";

            src = ./.;

            nativeBuildInputs = [ pkgs.zig ];

            buildPhase = ''
              echo "Building project..."
              export XDG_CACHE_HOME=".cache"
              zig build --summary all -Denable-demo=true
            '';

            installPhase = ''
              echo "Installing project..."
              mkdir -p $out/bin
              #cp zig-out/bin/apeiron $out/bin/
              cp -r zig-out/bin $out/ 
            '';
          };
        };

        devShell = pkgs.mkShell {
          nativeBuildInputs = [ pkgs.zig pkgs.cloc ];
          shellHook = ''
            LS_COLORS=$LS_COLORS:'tw=32' ; export LS_COLORS
            LS_COLORS=$LS_COLORS:'ow=34' ; export LS_COLORS
          '';
        };

        apps = {
          run-tests = { 
            type = "app";
            program = "${pkgs.writeScript "run-tests" ''
              ${pkgs.zig}/bin/zig test "$@"
            ''}";
            passthru = true;
          };
        };

        defaultPackage = self.packages.${system}.apeiron-core;
      });
}

