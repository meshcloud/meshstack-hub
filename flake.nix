{
  description = "Flake for meshstack-hub";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-24.05";
  };

  outputs = { self, nixpkgs }:

  let
    # These tools are pre-installed in github actions, so we can save the time for installing them.
    github_actions_preinstalled = pkgs:
      with pkgs;
      [
        awscli2
        (azure-cli.withExtensions [ azure-cli.extensions.account ])
        nodejs
      ];

    # core packages required in CI and not preinstalled in github actions
    core_packages = pkgs:
      let
        tofu_terraform =
          pkgs.stdenv.mkDerivation {
            name = "tofu-terraform";
            phases = [ "installPhase" ];
            installPhase = ''
              mkdir -p $out/bin
              echo '#!/usr/bin/env sh' > $out/bin/terraform
              echo 'tofu "$@"' >> $out/bin/terraform
              chmod +x $out/bin/terraform
            '';
          };
      in
      with pkgs;
      [
        opentofu
        terragrunt
        tflint
        tfupdate
        terraform-docs
        tofu_terraform
        jq
        pre-commit
      ];

    importNixpkgs = system: import nixpkgs { inherit system; };

    defaultShellForSystem = system:
      let
        pkgs = importNixpkgs system;
      in {
        default = pkgs.mkShell {
          name = "meshstack-hub";
          packages = (github_actions_preinstalled pkgs) ++ (core_packages pkgs);
        };

        website = pkgs.mkShell {
          name = "Website Development Shell";
          packages = (core_packages pkgs) ++ [
            pkgs.nodejs_20
            pkgs.yarn
          ];
          shellHook = ''
            if [ ! -d node_modules ]; then
              npm install -g npm@latest
            fi
            npm install gray-matter
          '';
        };
      };

  in {
    devShells = {
      aarch64-darwin = defaultShellForSystem "aarch64-darwin";
      x86_64-darwin = defaultShellForSystem "x86_64-darwin";
      x86_64-linux = defaultShellForSystem "x86_64-linux" // {
        github_actions =
          let
            pkgs = importNixpkgs "x86_64-linux";
          in
          pkgs.mkShell {
            name = "meshstack-hub-ghactions";
            packages = (core_packages pkgs);
          };
      };
    };
  };
}
