{
  description = "Tools the meshStack NoOp building block calls from Terraform";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: {
        awscli2 = nixpkgs.legacyPackages.${system}.awscli2;
      });
    };
}
