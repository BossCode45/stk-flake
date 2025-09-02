{
    description = "STK-server";
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    };
    outputs = { self, nixpkgs, ... }@inputs:
        let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in
          {
              nixosModules.superTuxKarts = import ./module.nix;
              nixosModules.default = self.nixosModules.superTuxKarts;
          };
}
