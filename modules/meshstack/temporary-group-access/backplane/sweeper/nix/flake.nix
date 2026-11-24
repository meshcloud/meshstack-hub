{
  description = "Tools the sweeper of meshStack Temporary Group Access calls from Terraform";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: {
        curl = nixpkgs.legacyPackages.${system}.curl;
        jq = nixpkgs.legacyPackages.${system}.jq;
      });
    };
}
