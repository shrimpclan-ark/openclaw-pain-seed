{ pkgs, army_type ? "sapper", enable_remote_access ? false, ... }: {
  packages = [ pkgs.nodejs_22 ];
  bootstrap = ''
    # Create the output directory
    mkdir -p "$out"

    # Copy all repository files from the Nix store to the workspace output
    cp -rf ${./.}/* "$out/"
    
    # Overwrite the dev.nix configuration with the selected one
    mkdir -p "$out/.idx"
    cp -f ${./envs}/dev-${army_type}.nix "$out/.idx/dev.nix"

    # Inject ENABLE_REMOTE_ACCESS env var based on user's checkbox selection
    ${if enable_remote_access then ''
      sed -i 's|TS_SOCKET = "/tmp/tailscaled.sock";|TS_SOCKET = "/tmp/tailscaled.sock";\n    ENABLE_REMOTE_ACCESS = "true";|' "$out/.idx/dev.nix"
    '' else ""}

    # Clean up template-specific files that are not needed in the final workspace
    rm -rf "$out/idx-template.json" "$out/idx-template.nix" "$out/envs"
    
    # Make all files writable by the user
    chmod -R u+w "$out"
  '';
}
