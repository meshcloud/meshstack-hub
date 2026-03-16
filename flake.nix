{
  description = "Flake for meshstack-hub";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    unstable.url = "github:nixos/nixpkgs?ref=master";
  };

  outputs = { self, nixpkgs, unstable }:

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
    core_packages = pkgs: unstable_pkgs:
      with pkgs;
      [
        unstable_pkgs.opentofu
        tflint
        tfupdate
        terraform-docs
        jq
        pre-commit
        pngquant
      ];

    # Go toolchain for tools/ development
    go_packages = pkgs:
      with pkgs;
      [
        go
        golangci-lint
        go-task
      ];

    importNixpkgs = system: import nixpkgs { inherit system; };

    defaultShellForSystem = system:
      let
        pkgs = importNixpkgs system;
        unstable_pkgs = import unstable { inherit system; };
      in {
        default = pkgs.mkShell {
          name = "meshstack-hub";
          packages = (github_actions_preinstalled pkgs) ++ (core_packages pkgs unstable_pkgs) ++ (go_packages pkgs);
        };

        website = pkgs.mkShell {
          name = "Website Development Shell";
          packages = (core_packages pkgs unstable_pkgs) ++ (go_packages pkgs) ++ [
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
            unstable_pkgs = import unstable { system = "x86_64-linux"; };
          in
          pkgs.mkShell {
            name = "meshstack-hub-ghactions";
            packages = (core_packages pkgs unstable_pkgs);
          };
      };
    };
  };
}
