{ pkgs, army_type ? "sapper", ... }: {
  packages = [ pkgs.nodejs_22 ];
  bootstrap = ''
    # Create the output directory
    mkdir -p "$out"

    # Copy all repository files from the Nix store to the workspace output
    cp -rf ${./.}/* "$out/"
    
    # Overwrite the dev.nix configuration with the selected one
    mkdir -p "$out/.idx"
    cp -f ${./envs}/dev-${army_type}.nix "$out/.idx/dev.nix"
    
    # Clean up template-specific files that are not needed in the final workspace
    rm -rf "$out/idx-template.json" "$out/idx-template.nix" "$out/envs"
    
    # Make all files writable by the user
    chmod -R u+w "$out"
  '';
}
