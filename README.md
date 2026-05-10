# dev-setup

One-command installer for Microsoft internal AI toolkits. No technical experience required — the wizard walks you through everything.

## What This Installs

| Toolkit | What It Does |
|---|---|
| **MCAPS-IQ** | AI-powered field intelligence for Microsoft sellers |
| **KATE** | Knowledge-Augmented Technical Engagement assistant |
| **LCG** | "Let Copilot Go!" — AI Chief of Staff toolkit |

All three live in [Microsoft's internal GitHub](https://github.com/microsoft). You pick which one you want during setup.

---

## Prerequisites

**You need:**
- A Windows, Mac, or Linux computer
- Internet access

**You do NOT need:**
- Any technical knowledge
- Any pre-installed software (the installer handles everything)

---

## Install (One Command)

### Windows

1. Click the **Start** button → type **PowerShell** → click **Windows PowerShell**
2. Copy-paste this entire line and press **Enter**:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force; irm "https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.ps1" | iex
```

### Mac

1. Open **Terminal** (press `Cmd + Space`, type "Terminal", press Enter)
2. Copy-paste this entire line and press **Enter**:

```bash
curl -fsSL https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.sh | bash
```

### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.sh | bash
```

---

## What the Wizard Does

The setup takes about 5–10 minutes and walks you through 7 steps:

| Step | What Happens |
|---|---|
| **1. Install tools** | Automatically installs Git and GitHub CLI |
| **2. GitHub account** | Walks you through creating a free personal GitHub account (if you don't have one) |
| **3. Join Microsoft org** | Guides you to link your personal GitHub to your Microsoft work account |
| **4. Sign in** | Opens a browser for you to log in to GitHub |
| **5. Pick a toolkit** | Shows a menu — you type 1, 2, or 3 |
| **6. Choose location** | Picks a folder on your computer (press Enter for the default) |
| **7. Download & setup** | Downloads the toolkit and runs its own setup |

You'll see friendly prompts at every step. If anything goes wrong, it tells you exactly how to fix it.

---

## FAQ

### Why do I need a personal GitHub account?

Microsoft's internal repos are hosted on GitHub under the `microsoft` organization. To access them, you need a GitHub account that has been linked to your Microsoft work identity. Your **personal** GitHub account (not your `_microsoft` EMU account) is what gets linked.

### How do I join the Microsoft GitHub organization?

Go to [https://repos.opensource.microsoft.com/link](https://repos.opensource.microsoft.com/link), sign in with your `@microsoft.com` work account, and follow the prompts to link your personal GitHub account. The setup wizard will walk you through this.

### What if I already have a GitHub account?

Great — the wizard will skip the account creation step. Just make sure your personal GitHub account is linked to the Microsoft org at [repos.opensource.microsoft.com](https://repos.opensource.microsoft.com/link).

### Can I install multiple toolkits?

Yes. Run the setup command again and pick a different toolkit. Each one installs to its own folder.

### What if something goes wrong?

Just run the same command again. The wizard picks up where you left off — it won't redo steps that are already complete.

### Where does it install?

By default, in your home folder:
- Windows: `C:\Users\<you>\<ToolkitName>`
- Mac/Linux: `~/ToolkitName`

You can choose a different folder during setup.

---

## Skip the Menu (Power Users)

Pre-select a toolkit by setting `SETUP_REPO`:

```powershell
# Windows — install LCG directly
$env:SETUP_REPO = "LCG"; irm "https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.ps1" | iex
```

```bash
# Mac/Linux — install KATE directly
SETUP_REPO=KATE curl -fsSL https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.sh | bash
```

Valid values: `MCAPS-IQ`, `KATE`, `LCG`, or any `owner/repo` path.

---

## For Maintainers

### Adding a new toolkit

Edit the `$Catalog` table in [install.ps1](install.ps1) and the `CATALOG` array in [install.sh](install.sh):

```powershell
# install.ps1 — add a new entry to $Catalog
4 = @{
  Key         = 'NewTool'
  Owner       = 'microsoft'
  Name        = 'NewTool'
  Description = 'Description of the new toolkit'
}
```

```bash
# install.sh — add to CATALOG array
"NewTool|microsoft|NewTool|Description of the new toolkit"
```

### Bootstrap convention: `.setup.json`

Each toolkit repo can include a `.setup.json` at its root to declare its bootstrap entry point:

```json
{
  "name": "LCG",
  "bootstrap": {
    "windows": "scripts/bootstrap.ps1",
    "unix": "scripts/bootstrap.sh"
  }
}
```

If `.setup.json` is absent, the installer looks for these files in order:

| Windows | Mac / Linux |
|---|---|
| `scripts/bootstrap.ps1` | `scripts/bootstrap.sh` |
| `scripts/setup.ps1` | `scripts/setup.sh` |
| `scripts/install.ps1` | `scripts/install.sh` |
| `bootstrap.ps1` | `bootstrap.sh` |
| `setup.ps1` | `setup.sh` |

### Architecture

```
User runs one-liner
        │
        ▼
┌─────────────────────────┐
│  dev-setup (this repo)  │  ← PUBLIC, no secrets
│  install.ps1 / .sh      │
└────────┬────────────────┘
         │  1. Install git + gh CLI
         │  2. Guide GitHub account creation
         │  3. Guide Microsoft org linking
         │  4. gh auth login (device code)
         │  5. Repo selection menu
         │  6. gh repo clone (authenticated)
         ▼
┌─────────────────────────┐
│  Target repo (PRIVATE)  │  ← microsoft/MCAPS-IQ, KATE, or LCG
│  .setup.json             │
│  scripts/bootstrap.*     │
└────────┬────────────────┘
         │  7. Run repo's own bootstrap
         │     (prereqs, dependencies,
         │      env setup, vault scaffold)
         ▼
      ✔ Done
```

## License

MIT
