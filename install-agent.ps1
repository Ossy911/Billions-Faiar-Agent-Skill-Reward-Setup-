# ============================================================
#  Billions Network — FAIAR Verified Agent Identity Installer
#  Platform: Windows (PowerShell 5.1+)
# ============================================================

$ErrorActionPreference = "Stop"

$SKILL_REPO  = "https://github.com/BillionsNetwork/verified-agent-identity.git"
$SKILL_NAME  = "verified-agent-identity"

$INSTALL_DIRS = @(
  "$HOME\verified-agent-identity",
  "$HOME\.claude\skills\verified-agent-identity",
  "$HOME\.cursor\skills\verified-agent-identity",
  "$HOME\.cline\skills\verified-agent-identity",
  "$HOME\.continue\skills\verified-agent-identity",
  "$HOME\.config\clawhub\skills\verified-agent-identity",
  "$HOME\.clawhub\skills\verified-agent-identity"
)
$IDENTITY_FILES = @(".identity", "identity.json", ".env", "agent.json")

function Write-Banner {
  Write-Host ""
  Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
  Write-Host "║     Billions Network · FAIAR Agent Identity Setup    ║" -ForegroundColor Cyan
  Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
  Write-Host ""
}

function Write-Info    { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn    { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Step    { param($msg) Write-Host "`n── $msg ──" -ForegroundColor White }
function Write-Err     { param($msg) Write-Host "[ERR]   $msg" -ForegroundColor Red; exit 1 }

# ── 1. Check / install Node.js + Git ────────────────────────
Write-Step "Checking dependencies"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Warn "Node.js not found. Attempting install via winget..."
  try {
    winget install OpenJS.NodeJS --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
  } catch {
    Write-Err "Could not auto-install Node.js. Please install from https://nodejs.org and re-run."
  }
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Warn "Git not found. Attempting install via winget..."
  try {
    winget install Git.Git --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
  } catch {
    Write-Err "Could not auto-install Git. Please install from https://git-scm.com and re-run."
  }
}

$nodeVer = node -v
$gitVer  = (git --version).Split(" ")[2]
Write-Success "Node $nodeVer · Git $gitVer"

# ── 2. Decide identity intent ────────────────────────────────
Write-Step "Detecting identity intent"

$IdentityMode = ""
$ExistingDir  = ""
$PrivateKey   = ""
$AgentName    = ""
$AgentDesc    = ""

# Check env var
if ($env:BILLIONS_PRIVATE_KEY) {
  $PrivateKey   = $env:BILLIONS_PRIVATE_KEY
  $IdentityMode = "env"
  Write-Info "Found BILLIONS_PRIVATE_KEY in environment — will import."
}

# Check existing install
if (-not $IdentityMode) {
  foreach ($dir in $INSTALL_DIRS) {
    if (Test-Path $dir) {
      foreach ($idf in $IDENTITY_FILES) {
        if (Test-Path "$dir\$idf") {
          $ExistingDir = $dir
          break
        }
      }
    }
    if ($ExistingDir) { break }
  }

  if ($ExistingDir) {
    Write-Warn "Existing identity found at: $ExistingDir"
    $ans = Read-Host "Reuse it? [Y/n]"
    if ($ans -ne "n" -and $ans -ne "N") {
      $IdentityMode = "reuse"
      Write-Success "Reusing existing identity."
    }
  }
}

# Ask user
if (-not $IdentityMode) {
  Write-Host ""
  Write-Host "  Choose identity option:" -ForegroundColor White
  Write-Host "  [1] Import an existing Ethereum private key"
  Write-Host "  [2] Generate a brand-new identity"
  Write-Host ""
  $choice = Read-Host "  Enter choice [1/2]"

  switch ($choice) {
    "1" {
      $IdentityMode = "import"
      $secKey = Read-Host "  Paste your private key" -AsSecureString
      $bstr   = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secKey)
      $PrivateKey = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
      if (-not $PrivateKey) { Write-Err "No private key provided." }
    }
    "2" {
      $IdentityMode = "generate"
      $AgentName = Read-Host "  Agent name"
      $AgentDesc = Read-Host "  Agent description"
      if (-not $AgentName) { Write-Err "Agent name cannot be empty." }
    }
    default { Write-Err "Invalid choice. Please enter 1 or 2." }
  }
}

# ── 3. Install the skill ─────────────────────────────────────
Write-Step "Installing Verified Agent Identity skill"

$SkillDir = ""

function Install-ViaClawHub {
  Write-Info "Trying ClawHub install..."
  try {
    npx clawhub@latest install $SKILL_NAME --yes 2>$null
    foreach ($dir in $INSTALL_DIRS) {
      if (Test-Path "$dir\package.json") {
        $script:SkillDir = $dir
        return $true
      }
    }
  } catch {}
  return $false
}

function Install-ViaGit {
  Write-Info "Falling back to git clone..."
  $script:SkillDir = "$HOME\verified-agent-identity"
  if (Test-Path "$($script:SkillDir)\.git") {
    Write-Info "Repo already cloned — pulling latest..."
    git -C $script:SkillDir pull --quiet
  } else {
    git clone --quiet $SKILL_REPO $script:SkillDir
  }
  Set-Location $script:SkillDir
  npm install --silent
  npm install --silent shell-quote @iden3/js-iden3-auth ethers@6 uuid
}

if ($IdentityMode -eq "reuse" -and $ExistingDir) {
  $SkillDir = $ExistingDir
  Write-Success "Using existing skill directory: $SkillDir"
} else {
  $installed = Install-ViaClawHub
  if (-not $installed) { Install-ViaGit }
  Write-Success "Skill installed at: $SkillDir"
}

Set-Location $SkillDir

# ── 4. Set up Ethereum identity ──────────────────────────────
Write-Step "Setting up agent Ethereum identity"

switch ($IdentityMode) {
  "reuse" {
    Write-Info "Skipping — reusing existing identity."
  }
  { $_ -in "env","import" } {
    Write-Info "Creating identity from provided private key..."
    node scripts/createNewEthereumIdentity.js --key $PrivateKey
    Write-Success "Identity created from existing key."
  }
  "generate" {
    Write-Info "Generating a new Ethereum identity..."
    Write-Host ""
    node scripts/createNewEthereumIdentity.js
    Write-Host ""
    Write-Host "⚠  IMPORTANT: Copy your private key above before continuing." -ForegroundColor Yellow
    Write-Host "   It will NOT be shown again." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press ENTER once you've backed up your key"
    Write-Success "New identity generated."
  }
}

# ── 5. Link Billions account ─────────────────────────────────
if ($IdentityMode -eq "generate") {
  Write-Step "Linking your Billions account to the agent"
  Write-Info "Generating verification link..."
  Write-Host ""

  # PowerShell requires careful quoting for JSON in --challenge
  $challengeJson = "{""name"":""$AgentName"",""description"":""$AgentDesc""}"
  node scripts/manualLinkHumanToAgent.js --challenge $challengeJson

  Write-Host ""
  Write-Host "👆 Open the URL above in your browser and sign in to your Billions account." -ForegroundColor Cyan
  Write-Host "   This binds your agent address to your Billions account for FAIAR rewards."
  Write-Host ""
  Read-Host "Press ENTER once you've completed the browser verification"
  Write-Success "Account linking initiated."
} else {
  Write-Info "Skipping account link (not needed for reuse/import mode)."
}

# ── 6. Register skill with AI agent ─────────────────────────
Write-Step "Registering skill with your AI agent"
Write-Info "Running skills picker..."
Write-Host ""
npx skills add BillionsNetwork/verified-agent-identity

# ── Done ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        ✅  Setup complete! You're FAIAR-eligible.    ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. Visit https://billions.network and register for Season 1"
Write-Host "  2. Link your wallet + social accounts"
Write-Host "  3. Share your referral link to earn bonus POWER points"
Write-Host ""
Write-Host "  Resources:"  -ForegroundColor White
Write-Host "  • FAIAR program : https://billions.network/verified-agent-identity-skill-openclaw"
Write-Host "  • Discord       : https://discord.com/invite/billions-ntwk/#support"
Write-Host ""
