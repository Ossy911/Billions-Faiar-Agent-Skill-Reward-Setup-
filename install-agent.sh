#!/usr/bin/env bash
# ============================================================
#  Billions Network — FAIAR Verified Agent Identity Installer
#  Supports: Linux · macOS · Termux (Android)
# ============================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

SKILL_REPO="https://github.com/BillionsNetwork/verified-agent-identity.git"
SKILL_NAME="verified-agent-identity"
INSTALL_DIRS=(
  "$HOME/verified-agent-identity"
  "$HOME/.claude/skills/verified-agent-identity"
  "$HOME/.cursor/skills/verified-agent-identity"
  "$HOME/.cline/skills/verified-agent-identity"
  "$HOME/.continue/skills/verified-agent-identity"
  "$HOME/.config/clawhub/skills/verified-agent-identity"
  "$HOME/.clawhub/skills/verified-agent-identity"
)
IDENTITY_FILES=(".identity" "identity.json" ".env" "agent.json")

print_banner() {
  echo -e ""
  echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
  echo -e "${CYAN}${BOLD}║     Billions Network · FAIAR Agent Identity Setup    ║${RESET}"
  echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
  echo -e ""
}

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR]${RESET}   $*"; exit 1; }
step()    { echo -e "\n${BOLD}── $* ──${RESET}"; }

# ── 1. Detect OS / package manager ──────────────────────────
detect_pkg_manager() {
  if command -v pkg &>/dev/null && [[ -d /data/data/com.termux ]]; then
    echo "termux"
  elif command -v apt-get &>/dev/null; then
    echo "apt"
  elif command -v dnf &>/dev/null; then
    echo "dnf"
  elif command -v pacman &>/dev/null; then
    echo "pacman"
  elif command -v apk &>/dev/null; then
    echo "apk"
  elif command -v brew &>/dev/null; then
    echo "brew"
  else
    echo "unknown"
  fi
}

install_node() {
  local mgr
  mgr=$(detect_pkg_manager)
  info "Installing Node.js via $mgr..."
  case "$mgr" in
    termux)  pkg install -y nodejs git ;;
    apt)     sudo apt-get update -qq && sudo apt-get install -y nodejs npm git ;;
    dnf)     sudo dnf install -y nodejs npm git ;;
    pacman)  sudo pacman -Sy --noconfirm nodejs npm git ;;
    apk)     sudo apk add --no-cache nodejs npm git ;;
    brew)    brew install node git ;;
    *)       error "Cannot auto-install Node.js. Please install it from https://nodejs.org and re-run." ;;
  esac
}

# ── 2. Ensure Node.js + Git ──────────────────────────────────
step "Checking dependencies"
if ! command -v node &>/dev/null; then
  warn "Node.js not found."
  install_node
fi
if ! command -v git &>/dev/null; then
  warn "Git not found."
  install_node   # install_node also installs git for most managers
fi
success "Node $(node -v) · Git $(git --version | awk '{print $3}')"

# ── 3. Decide identity intent ────────────────────────────────
step "Detecting identity intent"

IDENTITY_MODE=""   # reuse | import | env | generate
EXISTING_DIR=""
PRIVATE_KEY=""
AGENT_NAME=""
AGENT_DESC=""

# Check env var first
if [[ -n "${BILLIONS_PRIVATE_KEY:-}" ]]; then
  PRIVATE_KEY="$BILLIONS_PRIVATE_KEY"
  IDENTITY_MODE="env"
  info "Found BILLIONS_PRIVATE_KEY in environment — will import."
fi

# Check for existing install
if [[ -z "$IDENTITY_MODE" ]]; then
  for dir in "${INSTALL_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      for idf in "${IDENTITY_FILES[@]}"; do
        if [[ -f "$dir/$idf" ]]; then
          EXISTING_DIR="$dir"
          break 2
        fi
      done
    fi
  done

  if [[ -n "$EXISTING_DIR" ]]; then
    echo -e ""
    warn "Existing identity found at: $EXISTING_DIR"
    read -rp "Reuse it? [Y/n]: " reuse_ans
    if [[ "${reuse_ans,,}" != "n" ]]; then
      IDENTITY_MODE="reuse"
      success "Reusing existing identity."
    fi
  fi
fi

# Ask user to choose if not yet decided
if [[ -z "$IDENTITY_MODE" ]]; then
  echo -e ""
  echo -e "  ${BOLD}Choose identity option:${RESET}"
  echo -e "  [1] Import an existing Ethereum private key"
  echo -e "  [2] Generate a brand-new identity"
  echo -e ""
  read -rp "  Enter choice [1/2]: " choice
  case "$choice" in
    1)
      IDENTITY_MODE="import"
      read -rsp "  Paste your private key (input hidden): " PRIVATE_KEY
      echo ""
      [[ -z "$PRIVATE_KEY" ]] && error "No private key provided."
      ;;
    2)
      IDENTITY_MODE="generate"
      read -rp "  Agent name: " AGENT_NAME
      read -rp "  Agent description: " AGENT_DESC
      [[ -z "$AGENT_NAME" ]] && error "Agent name cannot be empty."
      ;;
    *)
      error "Invalid choice. Please enter 1 or 2."
      ;;
  esac
fi

# ── 4. Install the skill ─────────────────────────────────────
step "Installing Verified Agent Identity skill"

SKILL_DIR=""

install_via_clawhub() {
  info "Trying ClawHub install..."
  if npx clawhub@latest install "$SKILL_NAME" --yes 2>/dev/null; then
    # Find where clawhub installed it
    for dir in "${INSTALL_DIRS[@]}"; do
      if [[ -f "$dir/package.json" ]]; then
        SKILL_DIR="$dir"
        return 0
      fi
    done
  fi
  return 1
}

install_via_git() {
  info "Falling back to git clone..."
  SKILL_DIR="$HOME/verified-agent-identity"
  if [[ -d "$SKILL_DIR/.git" ]]; then
    info "Repo already cloned — pulling latest..."
    git -C "$SKILL_DIR" pull --quiet
  else
    git clone --quiet "$SKILL_REPO" "$SKILL_DIR"
  fi
  cd "$SKILL_DIR"
  npm install --silent
  npm install --silent shell-quote @iden3/js-iden3-auth ethers@6 uuid
}

if [[ "$IDENTITY_MODE" == "reuse" && -n "$EXISTING_DIR" ]]; then
  SKILL_DIR="$EXISTING_DIR"
  success "Using existing skill directory: $SKILL_DIR"
else
  install_via_clawhub || install_via_git
  success "Skill installed at: $SKILL_DIR"
fi

cd "$SKILL_DIR"

# ── 5. Set up Ethereum identity ──────────────────────────────
step "Setting up agent Ethereum identity"

case "$IDENTITY_MODE" in
  reuse)
    info "Skipping — reusing existing identity."
    ;;
  env|import)
    info "Creating identity from provided private key..."
    node scripts/createNewEthereumIdentity.js --key "$PRIVATE_KEY"
    success "Identity created from existing key."
    ;;
  generate)
    info "Generating a new Ethereum identity..."
    echo ""
    node scripts/createNewEthereumIdentity.js
    echo ""
    echo -e "${YELLOW}${BOLD}⚠  IMPORTANT: Copy your private key above before continuing.${RESET}"
    echo -e "${YELLOW}   It will NOT be shown again.${RESET}"
    echo ""
    read -rp "Press ENTER once you've backed up your key..."
    success "New identity generated."
    ;;
esac

# ── 6. Link Billions account ─────────────────────────────────
if [[ "$IDENTITY_MODE" == "generate" ]]; then
  step "Linking your Billions account to the agent"
  info "Generating verification link..."
  echo ""

  CHALLENGE_JSON="{\"name\":\"${AGENT_NAME}\",\"description\":\"${AGENT_DESC}\"}"
  node scripts/manualLinkHumanToAgent.js --challenge "$CHALLENGE_JSON"

  echo ""
  echo -e "${CYAN}${BOLD}👆 Open the URL above in your browser and sign in to your Billions account.${RESET}"
  echo -e "   This binds your agent's address to your Billions account for FAIAR rewards."
  echo ""
  read -rp "Press ENTER once you've completed the browser verification..."
  success "Account linking initiated."
else
  info "Skipping account link (not needed for reuse/import mode)."
fi

# ── 7. Register skill with AI agent ─────────────────────────
step "Registering skill with your AI agent"
info "Running skills picker..."
echo ""
npx skills add BillionsNetwork/verified-agent-identity

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║        ✅  Setup complete! You're FAIAR-eligible.    ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo -e "  1. Visit ${CYAN}https://billions.network${RESET} and register for Season 1"
echo -e "  2. Link your wallet + social accounts"
echo -e "  3. Share your referral link to earn bonus POWER points"
echo ""
echo -e "  ${BOLD}Resources:${RESET}"
echo -e "  • FAIAR program : https://billions.network/verified-agent-identity-skill-openclaw"
echo -e "  • Discord       : https://discord.com/invite/billions-ntwk/#support"
echo ""
