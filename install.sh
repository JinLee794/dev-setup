#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# Microsoft IQ Toolkit — Setup Wizard (macOS / Linux)
# ──────────────────────────────────────────────────────────────────────
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.sh | bash
#
# Pre-select a toolkit:
#   SETUP_REPO=LCG curl -fsSL https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.sh | bash
#
# This script is PUBLIC. No secrets or credentials.
# ──────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────
REPO="${SETUP_REPO:-}"
DIR="${SETUP_DIR:-}"
REF="${SETUP_REF:-main}"
FORCE=0

# ── Repo catalog ──────────────────────────────────────────────────────
# Format: "key|owner|name|description"
CATALOG=(
  "MCAPS-IQ|microsoft|MCAPS-IQ|MCAPS Intelligence — AI-powered field intelligence"
  "KATE|microsoft|KATE|KATE — Knowledge-Augmented Technical Engagement"
  "LCG|microsoft|LCG|LCG — Let Copilot Go! AI Chief of Staff toolkit"
)

# ── Parse arguments ───────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)   REPO="$2"; shift 2 ;;
    --dir)    DIR="$2"; shift 2 ;;
    --ref)    REF="$2"; shift 2 ;;
    --force)  FORCE=1; shift ;;
    --help|-h)
      cat <<'EOF'
Usage: install.sh [--repo <name>] [--dir <path>] [--ref <branch>] [--force]

Setup wizard for Microsoft internal AI toolkits.
Installs prerequisites, walks you through GitHub setup, and installs
your chosen toolkit (MCAPS-IQ, KATE, or LCG).

Environment variables:
  SETUP_REPO   Pre-select a toolkit (MCAPS-IQ, KATE, LCG, or owner/repo)
  SETUP_DIR    Install directory (default: ~/<repo-name>)
  SETUP_REF    Git branch to clone (default: main)
EOF
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────
C_RESET='\033[0m'; C_CYAN='\033[36m'; C_GREEN='\033[32m'
C_YELLOW='\033[33m'; C_RED='\033[31m'; C_BLUE='\033[34m'
C_WHITE='\033[97m'; C_GRAY='\033[90m'; C_BOLD='\033[1m'

banner() {
  echo ''
  echo -e "  ${C_CYAN}╔══════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "  ${C_CYAN}║                                                          ║${C_RESET}"
  echo -e "  ${C_CYAN}║        Microsoft IQ Toolkit — Setup Wizard               ║${C_RESET}"
  echo -e "  ${C_CYAN}║                                                          ║${C_RESET}"
  echo -e "  ${C_CYAN}║   This will walk you through everything step by step.    ║${C_RESET}"
  echo -e "  ${C_CYAN}║   No technical knowledge required!                       ║${C_RESET}"
  echo -e "  ${C_CYAN}║                                                          ║${C_RESET}"
  echo -e "  ${C_CYAN}╚══════════════════════════════════════════════════════════╝${C_RESET}"
  echo ''
}

write_step() {
  local num="$1"; shift
  echo ''
  echo -e "  ${C_CYAN}── Step ${num} ─────────────────────────────────────────${C_RESET}"
  echo -e "  ${C_WHITE}$*${C_RESET}"
  echo ''
}

ok()    { echo -e "  ${C_GREEN}✔ $*${C_RESET}"; }
warn()  { echo -e "  ${C_YELLOW}⚠ $*${C_RESET}"; }
fail()  { echo -e "  ${C_RED}✖ $*${C_RESET}"; }
info()  { echo -e "  ${C_BLUE}→ $*${C_RESET}"; }

instruction_box() {
  echo ''
  echo -e "  ${C_YELLOW}┌──────────────────────────────────────────────────────────┐${C_RESET}"
  for line in "$@"; do
    printf "  ${C_YELLOW}│  %-56s  │${C_RESET}\n" "$line"
  done
  echo -e "  ${C_YELLOW}└──────────────────────────────────────────────────────────┘${C_RESET}"
  echo ''
}

# Read from terminal even when script is piped via curl | bash.
read_tty() {
  if [[ -t 0 ]]; then
    read "$@"
  elif [[ -e /dev/tty ]]; then
    read "$@" </dev/tty
  else
    fail "Cannot read interactive input (no terminal available)."
    exit 1
  fi
}

prompt_continue() {
  local msg="${1:-Press Enter to continue...}"
  echo -ne "  ${C_GRAY}${msg}${C_RESET}"
  read_tty -r
}

ask_yn() {
  local prompt="$1" answer=""
  while [[ "$answer" != "Y" && "$answer" != "N" ]]; do
    echo -ne "  ${C_WHITE}${prompt} ${C_RESET}"
    read_tty -r answer
    answer="$(echo "$answer" | tr '[:lower:]' '[:upper:]')"
  done
  [[ "$answer" == "Y" ]]
}

is_cloud_synced() {
  local lower
  lower="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == *"onedrive"* || "$lower" == *"dropbox"* || \
     "$lower" == *"google drive"* || "$lower" == *"icloud"* ]]
}

open_url() {
  local url="$1"
  if command -v open >/dev/null 2>&1; then
    open "$url"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url"
  else
    info "Open this URL in your browser: $url"
  fi
}

lookup_catalog() {
  local key="$1"
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r ckey cowner cname cdesc <<< "$entry"
    if [[ "$ckey" == "$key" || "$cname" == "$key" ]]; then
      REPO_OWNER="$cowner"
      REPO_NAME="$cname"
      return 0
    fi
  done
  return 1
}

# ══════════════════════════════════════════════════════════════════════
banner

# ══════════════════════════════════════════════════════════════════════
# STEP 1: Install prerequisites
# ══════════════════════════════════════════════════════════════════════
write_step 1 'Installing required tools...'
echo -e "  ${C_GRAY}This may take a minute or two. Sit tight!${C_RESET}"
echo ''

# -- Git --
if command -v git >/dev/null 2>&1; then
  ok "Git is already installed ($(git --version 2>/dev/null | sed 's/git version //'))"
else
  info 'Installing Git...'
  installed=false

  if [[ "$(uname)" == "Darwin" ]]; then
    # macOS: xcode-select installs git
    if command -v xcode-select >/dev/null 2>&1; then
      xcode-select --install 2>/dev/null || true
      installed=true
    elif command -v brew >/dev/null 2>&1; then
      brew install git && installed=true
    fi
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq && sudo apt-get install -y git && installed=true
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y git && installed=true
  fi

  if ! command -v git >/dev/null 2>&1; then
    fail 'Could not install Git automatically.'
    echo ''
    instruction_box \
      'Please install Git manually:' \
      '' \
      '  macOS:  Open Terminal, type: xcode-select --install' \
      '  Linux:  sudo apt install git  (or equivalent)' \
      '' \
      'Then run this setup again.'
    exit 1
  fi
  ok 'Git installed!'
fi

# -- GitHub CLI --
if command -v gh >/dev/null 2>&1; then
  ok "GitHub CLI is already installed ($(gh --version 2>/dev/null | head -1 | sed 's/gh version //'))"
else
  info 'Installing GitHub CLI (needed to sign in)...'
  installed=false

  if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
    brew install gh && installed=true
  elif command -v apt-get >/dev/null 2>&1; then
    (
      type -p wget >/dev/null || sudo apt-get install -y wget
      sudo mkdir -p -m 755 /etc/apt/keyrings
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install -y gh
    ) && installed=true
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo 2>/dev/null || true
    sudo dnf install -y gh && installed=true
  fi

  if ! command -v gh >/dev/null 2>&1; then
    fail 'Could not install GitHub CLI automatically.'
    echo ''
    instruction_box \
      'Please install GitHub CLI manually:' \
      '' \
      '  Go to https://cli.github.com' \
      '  Follow the install instructions for your OS.' \
      '' \
      'Then run this setup again.'
    exit 1
  fi
  ok 'GitHub CLI installed!'
fi

echo ''
ok 'All required tools are ready.'

# ══════════════════════════════════════════════════════════════════════
# STEP 2: Ensure personal GitHub account
# ══════════════════════════════════════════════════════════════════════
write_step 2 'Setting up your GitHub account'

instruction_box \
  'You need a PERSONAL GitHub account to continue.' \
  '(This is separate from your Microsoft work account.)' \
  '' \
  'If you already have one — great! You will sign in next.' \
  '' \
  'If you do NOT have one yet, we will help you create' \
  'one right now.'

if ! ask_yn 'Do you already have a personal GitHub account? (Y/N)'; then
  echo ''
  echo -e "  ${C_GREEN}No problem! Let's create one.${C_RESET}"
  echo ''
  instruction_box \
    'CREATING A GITHUB ACCOUNT:' \
    '' \
    '  1. A browser will open to github.com/signup' \
    '  2. Use your PERSONAL email (Gmail, Outlook, etc.)' \
    '     Do NOT use your @microsoft.com email.' \
    '  3. Choose a username you will remember' \
    '  4. Follow the steps to verify your email' \
    '  5. Come back here when you are done'

  prompt_continue 'Press Enter to open GitHub signup in your browser...'
  open_url 'https://github.com/signup'

  echo ''
  echo -e "  ${C_GRAY}Take your time setting up your account.${C_RESET}"
  echo -e "  ${C_GRAY}When you are done, come back to this window.${C_RESET}"
  echo ''
  prompt_continue 'Press Enter when your GitHub account is ready...'
  ok 'Great! Moving on.'
fi

# ══════════════════════════════════════════════════════════════════════
# STEP 3: Join the Microsoft GitHub organization
# ══════════════════════════════════════════════════════════════════════
write_step 3 'Joining the Microsoft GitHub organization'

instruction_box \
  'The tools you are installing live in Microsoft'"'"'s' \
  'private GitHub. You need to link your personal GitHub' \
  'account to Microsoft to get access.' \
  '' \
  'If you have ALREADY done this — just press Enter.' \
  '' \
  'If you have NOT — follow these steps:'

echo -e "  ${C_WHITE}HOW TO JOIN (takes ~2 minutes):${C_RESET}"
echo ''
echo -e "  ${C_GRAY}  1. Go to ${C_CYAN}https://repos.opensource.microsoft.com/link${C_RESET}"
echo -e "  ${C_GRAY}  2. Sign in with your ${C_WHITE}@microsoft.com${C_GRAY} work account${C_RESET}"
echo -e "  ${C_GRAY}  3. It will ask you to link your ${C_WHITE}personal GitHub${C_GRAY} account${C_RESET}"
echo -e "  ${C_GRAY}  4. Authorize the connection when prompted${C_RESET}"
echo -e "  ${C_GRAY}  5. You should see a ${C_GREEN}\"Successfully linked\"${C_GRAY} message${C_RESET}"
echo ''

if ask_yn 'Do you need to link your account now? (Y/N)'; then
  open_url 'https://repos.opensource.microsoft.com/link'
  echo ''
  echo -e "  ${C_GRAY}Complete the linking in your browser, then come back here.${C_RESET}"
  echo ''
  prompt_continue 'Press Enter when you have linked your account...'
fi

ok 'Account setup complete.'

# ══════════════════════════════════════════════════════════════════════
# STEP 4: Sign in to GitHub
# ══════════════════════════════════════════════════════════════════════
write_step 4 'Signing in to GitHub'

if gh auth status >/dev/null 2>&1; then
  ok 'Already signed in to GitHub!'
else
  instruction_box \
    'A browser window will open for you to sign in.' \
    '' \
    'IMPORTANT: Sign in with your PERSONAL GitHub' \
    'account — the one you just linked to Microsoft.' \
    '' \
    'Do NOT use an account ending in _microsoft.' \
    '(If your browser auto-fills the wrong account,' \
    ' click "Use a different account".)'

  prompt_continue 'Press Enter to open the sign-in page...'

  gh auth login --web --git-protocol https -s read:org,repo,read:packages </dev/tty
  if ! gh auth status >/dev/null 2>&1; then
    fail 'Sign-in did not complete.'
    echo ''
    echo -e "  ${C_GRAY}No worries — just run this setup again and it will${C_RESET}"
    echo -e "  ${C_GRAY}pick up where you left off.${C_RESET}"
    exit 1
  fi
  ok 'Signed in successfully!'
fi

# Verify Microsoft org membership.
org_state="$(gh api user/memberships/orgs/microsoft --jq '.state' 2>/dev/null || echo '')"
if [[ "$org_state" == "active" ]]; then
  ok 'Microsoft org membership confirmed.'
else
  echo ''
  warn 'It looks like your account may not be linked to the Microsoft org yet.'
  echo ''
  echo -e "  ${C_GRAY}This is required to access the tools. If you skipped Step 3,${C_RESET}"
  echo -e "  ${C_GRAY}go to ${C_CYAN}https://repos.opensource.microsoft.com/link${C_GRAY} now.${C_RESET}"
  echo ''
  if ! ask_yn 'Try to continue anyway? (Y/N)'; then
    info 'No problem. Link your account, then run this setup again.'
    exit 1
  fi
fi

# ══════════════════════════════════════════════════════════════════════
# STEP 5: Choose a toolkit
# ══════════════════════════════════════════════════════════════════════
write_step 5 'Choosing which toolkit to install'

REPO_OWNER=""
REPO_NAME=""

if [[ -n "$REPO" ]]; then
  # Pre-selected via env var or argument.
  if [[ "$REPO" == */* ]]; then
    REPO_OWNER="${REPO%%/*}"
    REPO_NAME="${REPO#*/}"
  elif lookup_catalog "$REPO"; then
    : # REPO_OWNER and REPO_NAME set by lookup
  else
    fail "Unknown toolkit '$REPO'."
    exit 1
  fi
  ok "Pre-selected: $REPO_NAME"
else
  echo -e "  ${C_WHITE}Which toolkit would you like to install?${C_RESET}"
  echo ''

  idx=1
  for entry in "${CATALOG[@]}"; do
    IFS='|' read -r ckey cowner cname cdesc <<< "$entry"
    echo -e "    ${C_WHITE}${idx})${C_RESET} ${C_CYAN}${ckey}${C_RESET}${C_GRAY} — ${cdesc}${C_RESET}"
    idx=$((idx + 1))
  done
  echo ''

  choice=""
  while [[ -z "$choice" ]]; do
    echo -ne "  ${C_WHITE}Enter a number (1, 2, or 3): ${C_RESET}"
    read_tty -r raw
    if [[ "$raw" =~ ^[0-9]+$ ]] && [[ "$raw" -ge 1 ]] && [[ "$raw" -le "${#CATALOG[@]}" ]]; then
      choice="$raw"
    else
      echo -e "  ${C_YELLOW}That's not a valid option. Try again.${C_RESET}"
    fi
  done

  selected="${CATALOG[$((choice - 1))]}"
  IFS='|' read -r _ REPO_OWNER REPO_NAME _ <<< "$selected"
fi

REPO_SLUG="$REPO_OWNER/$REPO_NAME"
echo ''
ok "You chose: $REPO_NAME"

# ══════════════════════════════════════════════════════════════════════
# STEP 6: Choose install directory
# ══════════════════════════════════════════════════════════════════════
write_step 6 'Choosing where to install'

DEFAULT_DIR="$HOME/$REPO_NAME"

if [[ -z "$DIR" ]]; then
  echo -e "  ${C_GRAY}We will install to: ${C_WHITE}${DEFAULT_DIR}${C_RESET}"
  echo ''
  echo -e "  ${C_GRAY}Press Enter to accept, or type a different folder path.${C_RESET}"
  echo ''
  echo -ne "  Install location: "
  read_tty -r requested || true
  if [[ -z "$requested" ]]; then
    DIR="$DEFAULT_DIR"
  else
    DIR="${requested/#\~/$HOME}"
  fi
fi

DIR="$(cd "$(dirname "$DIR")" 2>/dev/null && pwd)/$(basename "$DIR")" 2>/dev/null || DIR="$DIR"

# Block cloud-synced paths.
if is_cloud_synced "$DIR"; then
  echo ''
  fail 'That folder is inside a cloud-synced location (OneDrive, Dropbox, etc.).'
  echo ''
  echo -e "  ${C_YELLOW}This can accidentally sync passwords to the cloud.${C_RESET}"
  echo -e "  ${C_YELLOW}Please choose a different folder, like: ${DEFAULT_DIR}${C_RESET}"
  echo ''
  echo -e "  ${C_GRAY}Run this setup again and pick a different location.${C_RESET}"
  exit 1
fi

if [[ -e "$DIR" && -n "$(ls -A "$DIR" 2>/dev/null)" ]]; then
  if [[ "$FORCE" -ne 1 ]]; then
    warn "That folder already exists and has files in it: $DIR"
    echo ''
    if ask_yn 'Delete it and start fresh? (Y/N)'; then
      FORCE=1
    else
      info 'No problem. Run setup again and choose a different folder.'
      exit 1
    fi
  fi
fi

ok "Installing to: $DIR"

# ══════════════════════════════════════════════════════════════════════
# STEP 7: Download and run repo bootstrap
# ══════════════════════════════════════════════════════════════════════
write_step 7 "Downloading $REPO_NAME"

if [[ -e "$DIR" && "$FORCE" -eq 1 && -n "$(ls -A "$DIR" 2>/dev/null)" ]]; then
  info 'Removing existing folder...'
  rm -rf "$DIR"
fi

mkdir -p "$(dirname "$DIR")"

echo -e "  ${C_GRAY}Downloading... this may take a minute.${C_RESET}"
gh repo clone "$REPO_SLUG" "$DIR" -- --branch "$REF" --depth 1

if [[ $? -ne 0 ]]; then
  echo ''
  fail "Could not download $REPO_NAME."
  echo ''
  echo -e "  ${C_YELLOW}This usually means one of:${C_RESET}"
  echo -e "  ${C_YELLOW}  - Your GitHub account is not linked to the Microsoft org${C_RESET}"
  echo -e "  ${C_YELLOW}  - You don't have access to this specific repo${C_RESET}"
  echo ''
  echo -e "  ${C_GRAY}To fix:${C_RESET}"
  echo -e "  ${C_GRAY}  1. Go to https://repos.opensource.microsoft.com/link${C_RESET}"
  echo -e "  ${C_GRAY}  2. Make sure your account is linked${C_RESET}"
  echo -e "  ${C_GRAY}  3. Run this setup again${C_RESET}"
  exit 1
fi

ok "Downloaded $REPO_NAME!"

# ── Discover and run the repo's bootstrap script ─────────────────────
echo ''
echo -e "  ${C_GRAY}Now running the toolkit's own setup...${C_RESET}"
echo -e "  ${C_GRAY}(This may install additional tools and ask more questions.)${C_RESET}"
echo ''

cd "$DIR"

BOOTSTRAP_SCRIPT=""

# 1. Check for .setup.json convention file.
if [[ -f ".setup.json" ]]; then
  unix_boot=$(grep -o '"unix"[[:space:]]*:[[:space:]]*"[^"]*"' .setup.json 2>/dev/null \
    | head -1 | sed 's/.*"unix"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  if [[ -n "$unix_boot" && -f "$unix_boot" ]]; then
    BOOTSTRAP_SCRIPT="$unix_boot"
  fi
fi

# 2. Fall back to conventional paths.
if [[ -z "$BOOTSTRAP_SCRIPT" ]]; then
  for candidate in \
    scripts/bootstrap.sh scripts/setup.sh scripts/install.sh \
    bootstrap.sh setup.sh; do
    if [[ -f "$candidate" ]]; then
      BOOTSTRAP_SCRIPT="$candidate"
      break
    fi
  done
fi

if [[ -z "$BOOTSTRAP_SCRIPT" ]]; then
  echo ''
  ok "Download complete! $REPO_NAME is ready at:"
  echo -e "  ${C_CYAN}${DIR}${C_RESET}"
  echo ''
  echo -e "  ${C_GRAY}Open that folder to get started.${C_RESET}"
  exit 0
fi

# When invoked via curl|bash, stdin is the pipe. Redirect from /dev/tty
# so the bootstrap script can read interactive input.
if [[ ! -t 0 ]] && [[ -e /dev/tty ]]; then
  exec bash "$BOOTSTRAP_SCRIPT" </dev/tty
else
  exec bash "$BOOTSTRAP_SCRIPT"
fi
