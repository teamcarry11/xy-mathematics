# Glow G2 steadies the shell: Tahoe env harness.
export PATH="$HOME/.local/bin:$PATH"
export LETTA_PROFILE_ROOT="$HOME/Library/Application Support/Tahoe"
export GRAIN_HOME="$HOME/.config/tahoe"
export GRAIN_LOG_LEVEL="info"

# Calm reminder: source persona memory for the climb.
export GLOW_G2_CONTACT_TWITTER="@risc_love"
export GLOW_G2_CONTACT_EMAIL="kj3x39@gmail.com"
export GLOW_G2_GPG_KEY="26F201F13AE3AFF90711006C1EE2C9E3486517CB"

# Tidy prompt: reference Tahoe theme if available.
if [ -f "$GRAIN_HOME/prompt.zsh" ]; then
  source "$GRAIN_HOME/prompt.zsh"
fi

# Letta CLI shim, ready for Matklad-style tests.
letta-shell() {
  command letta "$@"
}

# Grain supervisor alias.
alias grainctl="zig run $HOME/kae3g/bhagavan851c05a/tools/grainctl.zig --"

