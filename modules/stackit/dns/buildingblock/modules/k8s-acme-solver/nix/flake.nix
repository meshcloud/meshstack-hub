{
  description = "Tools the STACKIT cert-manager webhook calls from Terraform on destroy";

  inputs.nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    {
      packages = nixpkgs.lib.genAttrs systems (system: {
        jq = nixpkgs.legacyPackages.${system}.jq;
        kubectl = nixpkgs.legacyPackages.${system}.kubectl;
      });
    };
}
