{
  description = "Development environment for google-translate.nvim";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.neovim
            pkgs.curl
            pkgs.stylua
            pkgs.lua-language-server
            pkgs.luajitPackages.busted
            pkgs.luajitPackages.nlua
          ];
          VIMRUNTIME = "${pkgs.neovim-unwrapped}/share/nvim/runtime";
        };
      });
    };
}
