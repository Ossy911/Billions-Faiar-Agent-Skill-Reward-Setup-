# 🚀 Billions FAIAR Reward — Verified Agent Identity Installer

Qualify for the **Billions Network FAIAR reward** by adding the official
**Verified Agent Identity** skill to your AI agent (Claude Code, Cursor, Cline, etc.).
This repo gives you a **single command** that handles everything automatically.

---

## 🎁 About the FAIAR Reward

**FAIAR** (First AI Agent Rewards) is Billions Network's incentive program for
AI agents that carry a verified, human-backed on-chain identity. By installing
the `verified-agent-identity` skill, your agent becomes eligible to:

- ✅ Earn **$BILL token rewards** distributed by Billions Network
- ✅ Get listed as a **verified agent** in the Billions ecosystem
- ✅ Participate in upcoming **reputation drops & airdrops**
- ✅ Build a **verifiable reputation** that follows your agent across platforms
- ✅ Prove identity **privately** — zero personal data exposed (ZK proof tech)

### Eligibility checklist
1. You have an AI agent installed locally (Claude Code, Cursor, Cline, etc.)
2. You install the **Verified Agent Identity** skill using this guide
3. You complete the in-browser verification link printed at the end (new identities only)
4. You register at [billions.network](https://billions.network) before Season 1 closes

---

## ⚡ One-Line Install

### 🐧 Linux / 🍎 macOS / 📱 Termux (Android)
```bash
curl -sL https://raw.githubusercontent.com/Ossy911/Billions-Faiar-Agent-Skill-Reward-Setup/main/install-agent.sh | bash
```

### 🪟 Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/Ossy911/Billions-Faiar-Agent-Skill-Reward-Setup/main/install-agent.ps1 | iex
```

> The installer prompts you only when input is required. If a Billions identity
> is already on disk, or you supply your private key via environment variable,
> you won't be asked for an agent name or description — those are only needed
> for brand-new identities.

---

## 🔄 What the Installer Does

Both scripts (bash for Linux/macOS/Termux, PowerShell for Windows) follow the same flow:

### 1 · Decide identity intent
Before installing anything, the script checks:

- If `BILLIONS_PRIVATE_KEY` is set in your environment → it's imported directly.
- Else, if a previous install is found at one of:
  `~/verified-agent-identity`,
  `~/.claude/skills/verified-agent-identity`,
  `~/.cursor/skills/verified-agent-identity`,
  `~/.cline/skills/verified-agent-identity`,
  `~/.continue/skills/verified-agent-identity`,
  `~/.config/clawhub/skills/verified-agent-identity` —
  and contains an identity file (`.identity`, `identity.json`, `.env`, or `agent.json`),
  you're asked **`Reuse it? [Y/n]`**.
- Else you choose:
  - `[1]` **Import an existing private key** — paste it (input is hidden).
  - `[2]` **Generate a brand-new identity** — the new key is printed once.
    **Back it up before pressing ENTER** — it will not be shown again.

> Agent name & description are only requested in the "generate" branch.
> Reuse / env / import paths skip those prompts entirely.

### 2 · Install Node.js + Git (if missing)
Uses the right package manager for your OS:
`pkg` (Termux) · `apt-get` (Debian/Ubuntu) · `dnf` (Fedora) · `pacman` (Arch) · `apk` (Alpine) · `brew` (macOS) · `winget` (Windows)

### 3 · Install the skill files
Tries ClawHub first:
```bash
npx clawhub@latest install verified-agent-identity
```
Falls back to a direct git clone if ClawHub fails:
```bash
git clone https://github.com/BillionsNetwork/verified-agent-identity ~/verified-agent-identity
cd ~/verified-agent-identity && npm install
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid
```

### 4 · Set up the agent's Ethereum identity
- **Reuse** → skipped, existing key is preserved.
- **Env / import** → `node scripts/createNewEthereumIdentity.js --key <KEY>`
- **Generate** → `node scripts/createNewEthereumIdentity.js` + backup warning + ENTER gate.

### 5 · Link your Billions account to the agent
Only runs in **generate** mode (reused/imported identities are already linked).
```bash
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"...","description":"..."}'
```
Open the printed URL in your browser and sign in to your Billions account —
that handshake permanently binds your agent's address to your account.

### 6 · Register the skill with your AI agent
```bash
npx skills add BillionsNetwork/verified-agent-identity
```
Pick Claude Code / Cursor / Cline / Continue / etc. using `↑/↓` + `SPACE` + `ENTER`.

---

## 🔐 How Does the Agent Know Which Billions Account to Link To?

It doesn't — until you tell it. The link happens in two pieces:

1. The agent gets its own **Ethereum identity** (a keypair generated locally or imported
   via `--key`). That's the agent's on-chain address.
2. `scripts/manualLinkHumanToAgent.js` produces a **verification URL** on `billions.network`.
   When you open that URL while signed in to your Billions account, Billions records the
   binding *human account ↔ agent address*. The browser sign-in is the **only** place your
   Billions account identity comes from — the installer never touches it directly.

> If you skip step 5, the agent has an identity but no account attached and FAIAR rewards
> have nowhere to go. The installer only skips it when it has good reason to believe
> you've already done it (i.e. you provided the key or it was found on disk).

---

## 🆘 Troubleshooting

<details>
<summary><b>"npx: command not found"</b></summary>

The installer auto-installs Node.js, but if it fails:

- **Termux:** `pkg install nodejs`
- **Linux (Debian/Ubuntu):** `sudo apt install nodejs npm`
- **Linux (Fedora):** `sudo dnf install nodejs npm`
- **macOS:** `brew install node` (install Homebrew first from https://brew.sh)
- **Windows:** Download from https://nodejs.org/
</details>

<details>
<summary><b>"Permission denied" on Linux/macOS</b></summary>

Don't run the curl command with `sudo`. If a step needs root (e.g. installing Node),
the script will call `sudo` itself.
</details>

<details>
<summary><b>"Cannot find module 'shell-quote' / '@iden3/js-iden3-auth'"</b></summary>

```bash
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid
```

The installer pre-installs these in the git-clone fallback path, but if you ran the
manual steps you may need to install them yourself.
</details>

<details>
<summary><b>The agent picker doesn't show my agent</b></summary>

Make sure your agent is installed and has been launched at least once so its config
directory exists. Then re-run the one-line install command.
</details>

<details>
<summary><b>I want to skip the auto-installer and run steps manually</b></summary>

```bash
# 1. Try ClawHub first
npx clawhub@latest install verified-agent-identity

# 2. If ClawHub fails — clone the repo and install deps manually
cd ~
git clone https://github.com/BillionsNetwork/verified-agent-identity.git
cd verified-agent-identity
npm install shell-quote @iden3/js-iden3-auth ethers@6 uuid

# 3a. Generate a new identity...
node scripts/createNewEthereumIdentity.js
# 3b. ...or import an existing private key
node scripts/createNewEthereumIdentity.js --key <your-ethereum-private-key>

# 4. Link your Billions account (new identities only)
node scripts/manualLinkHumanToAgent.js --challenge '{"name":"My Agent","description":"AI agent verified via Billions FAIAR"}'

# 5. Register the skill with your AI agent
npx skills add BillionsNetwork/verified-agent-identity
```

**PowerShell:**
```powershell
npx clawhub@latest install verified-agent-identity
# ...same Node-script calls as above
# Use single-quoted JSON strings in PowerShell — see install-agent.ps1 for exact quoting
npx skills add BillionsNetwork/verified-agent-identity
```
</details>

---

## 🔑 Security Note

This installer runs `npx` commands published by **Billions Network** and **Clawhub**,
and may clone the public
[BillionsNetwork/verified-agent-identity](https://github.com/BillionsNetwork/verified-agent-identity)
repo as a fallback. You can audit the script before running it:

```bash
curl -sL https://raw.githubusercontent.com/Ossy911/Billions-Faiar-Agent-Skill-Reward-Setup/main/install-agent.sh | less
```

Your private key is **never sent anywhere** — it stays local and is only used to
generate your agent's Ethereum identity.

---

## 📅 Season 1 — Key Dates

| Milestone | Date |
|---|---|
| FAIAR announced | February 2026 |
| Verified Agent Identity Skill launched | March 5, 2026 |
| Season 1 registration opened | April 20, 2026 |
| Season 1 extended deadline | April 27, 2026 (09:00 CET) |
| Season 2 begins | Immediately after Season 1 closes |
| TGE (Token Generation Event) | TBA — monitor official channels |

> **Note:** Registration only confirms your participation. Eligibility and allocation
> details are not shown at registration time. Everything you did in Season 1 carries
> forward — but only if you register.

---

## 🔗 Links

| Resource | Link |
|---|---|
| Billions Network | https://billions.network |
| FAIAR Program | https://billions.network/verified-agent-identity-skill-openclaw |
| Verified Agent Identity (GitHub) | https://github.com/BillionsNetwork/verified-agent-identity |
| ClawHub Skill Page | https://clawhub.ai/OBrezhniev/verified-agent-identity |
| Billions App (iOS) | https://apps.apple.com/app/billions/id6742451067 |
| Billions App (Android) | https://play.google.com/store/apps/details?id=com.billions.app.mobile |
| Discord / Support | https://discord.com/invite/billions-ntwk/#support |

---

Built with ❤️ for the Billions Community
