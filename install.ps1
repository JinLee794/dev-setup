<#
.SYNOPSIS
  One-liner setup for Microsoft internal AI toolkits (MCAPS-IQ, KATE, LCG).

.DESCRIPTION
  Walks an absolute beginner through every step:
    1. Installs Git and GitHub CLI automatically
    2. Guides them to create a personal GitHub account (if needed)
    3. Helps them join the Microsoft GitHub organization
    4. Authenticates with GitHub
    5. Lets them pick which toolkit to install
    6. Clones and bootstraps it

  Invoke via:
    irm "https://raw.githubusercontent.com/JinLee794/dev-setup/main/install.ps1" | iex

.NOTES
  This script is PUBLIC. It contains no secrets or credentials.
  Authentication flows through GitHub's official device-code OAuth.
#>

function Install-DevSetup {
  [CmdletBinding()]
  param(
    [string]$Repo,
    [string]$Dir,
    [string]$Ref = 'main',
    [switch]$Force
  )

  $ErrorActionPreference = 'Stop'

  # Pick up env-var overrides (for piped irm | iex invocations).
  if (-not $Repo -and $env:SETUP_REPO) { $Repo = $env:SETUP_REPO }
  if (-not $Dir  -and $env:SETUP_DIR)  { $Dir  = $env:SETUP_DIR }
  if ($env:SETUP_REF) { $Ref = $env:SETUP_REF }

  # ── Repo catalog ────────────────────────────────────────────────
  $Catalog = [ordered]@{
    1 = @{
      Key         = 'MCAPS-IQ'
      Owner       = 'microsoft'
      Name        = 'MCAPS-IQ'
      Description = 'MCAPS Intelligence — AI-powered field intelligence'
    }
    2 = @{
      Key         = 'KATE'
      Owner       = 'microsoft'
      Name        = 'KATE'
      Description = 'KATE — Knowledge-Augmented Technical Engagement'
    }
    3 = @{
      Key         = 'LCG'
      Owner       = 'microsoft'
      Name        = 'LCG'
      Description = 'LCG — Let Copilot Go! AI Chief of Staff toolkit'
    }
  }

  # ── Helpers ─────────────────────────────────────────────────────

  function Write-Banner {
    Write-Host ''
    Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '  ║                                                          ║' -ForegroundColor Cyan
    Write-Host '  ║        Microsoft IQ Toolkit — Setup Wizard               ║' -ForegroundColor Cyan
    Write-Host '  ║                                                          ║' -ForegroundColor Cyan
    Write-Host '  ║   This will walk you through everything step by step.    ║' -ForegroundColor Cyan
    Write-Host '  ║   No technical knowledge required!                       ║' -ForegroundColor Cyan
    Write-Host '  ║                                                          ║' -ForegroundColor Cyan
    Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''
  }

  function Write-Step($num, $msg) {
    Write-Host ''
    Write-Host "  ── Step $num ─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  $msg" -ForegroundColor White
    Write-Host ''
  }

  function Write-Ok($msg)   { Write-Host "  ✔ $msg" -ForegroundColor Green }
  function Write-Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
  function Write-Fail($msg) { Write-Host "  ✖ $msg" -ForegroundColor Red }
  function Write-Info($msg) { Write-Host "  → $msg" -ForegroundColor Blue }

  function Write-Instruction {
    param([string[]]$Lines)
    Write-Host ''
    Write-Host '  ┌──────────────────────────────────────────────────────────┐' -ForegroundColor Yellow
    foreach ($line in $Lines) {
      $padded = $line.PadRight(56)
      Write-Host "  │  $padded  │" -ForegroundColor Yellow
    }
    Write-Host '  └──────────────────────────────────────────────────────────┘' -ForegroundColor Yellow
    Write-Host ''
  }

  function Prompt-Continue($msg = 'Press Enter to continue...') {
    Write-Host "  $msg" -ForegroundColor DarkGray -NoNewline
    try { $null = Read-Host } catch {}
  }

  function Test-CommandExists($cmd) {
    [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
  }

  function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
  }

  function Install-WithWinget($wingetId) {
    if (-not (Test-CommandExists 'winget')) { return $false }
    $proc = Start-Process -FilePath 'winget' -ArgumentList @(
      'install', '--id', $wingetId, '-e', '--silent',
      '--accept-package-agreements', '--accept-source-agreements'
    ) -Wait -PassThru -NoNewWindow
    Refresh-Path
    return ($proc.ExitCode -eq 0)
  }

  function Test-CloudSyncedPath($testPath) {
    $lower = $testPath.ToLower()
    return ($lower -match 'onedrive|dropbox|google drive|icloud')
  }

  # ── Start ───────────────────────────────────────────────────────
  Write-Banner

  # ══════════════════════════════════════════════════════════════════
  # STEP 1: Install Git + GitHub CLI (silently)
  # ══════════════════════════════════════════════════════════════════
  Write-Step 1 'Installing required tools...'
  Write-Host '  This may take a minute or two. Sit tight!' -ForegroundColor DarkGray
  Write-Host ''

  # -- Git --
  if (Test-CommandExists 'git') {
    $gitVer = (& git --version 2>$null) -replace 'git version ', ''
    Write-Ok "Git is already installed (v$gitVer)"
  } else {
    Write-Info 'Installing Git (needed to download code)...'
    $installed = Install-WithWinget 'Git.Git'

    if (-not $installed -and (Test-CommandExists 'choco')) {
      & choco install git -y 2>$null
      Refresh-Path
    }

    if (-not (Test-CommandExists 'git')) {
      Write-Fail 'Could not install Git automatically.'
      Write-Host ''
      Write-Instruction @(
        'Please install Git manually:',
        '',
        '  1. Go to https://git-scm.com/download/win',
        '  2. Download and run the installer',
        '  3. Use all the default options',
        '  4. Close this window and try again'
      )
      return 1
    }
    Write-Ok 'Git installed!'
  }

  # -- GitHub CLI --
  if (Test-CommandExists 'gh') {
    $ghVer = ((& gh --version 2>$null) | Select-Object -First 1) -replace 'gh version ', ''
    Write-Ok "GitHub CLI is already installed (v$ghVer)"
  } else {
    Write-Info 'Installing GitHub CLI (needed to sign in)...'
    $installed = Install-WithWinget 'GitHub.cli'

    if (-not $installed -and (Test-CommandExists 'choco')) {
      & choco install gh -y 2>$null
      Refresh-Path
    }

    # Probe well-known install directories as fallback.
    if (-not (Test-CommandExists 'gh')) {
      foreach ($p in @("$env:ProgramFiles\GitHub CLI", "${env:ProgramFiles(x86)}\GitHub CLI")) {
        if (Test-Path (Join-Path $p 'gh.exe')) {
          $env:Path = "$env:Path;$p"
          break
        }
      }
    }

    if (-not (Test-CommandExists 'gh')) {
      Write-Fail 'Could not install GitHub CLI automatically.'
      Write-Host ''
      Write-Instruction @(
        'Please install GitHub CLI manually:',
        '',
        '  1. Go to https://cli.github.com',
        '  2. Click "Download for Windows"',
        '  3. Run the installer',
        '  4. Close this window and try again'
      )
      return 1
    }
    Write-Ok 'GitHub CLI installed!'
  }

  Write-Host ''
  Write-Ok 'All required tools are ready.'

  # ══════════════════════════════════════════════════════════════════
  # STEP 2: Ensure user has a personal GitHub account
  # ══════════════════════════════════════════════════════════════════
  Write-Step 2 'Setting up your GitHub account'

  Write-Instruction @(
    'You need a PERSONAL GitHub account to continue.',
    '(This is separate from your Microsoft work account.)',
    '',
    'If you already have one — great! You will sign in next.',
    '',
    'If you do NOT have one yet, we will help you create',
    'one right now.'
  )

  $hasAccount = $null
  while ($hasAccount -ne 'Y' -and $hasAccount -ne 'N') {
    Write-Host '  Do you already have a personal GitHub account? ' -ForegroundColor White -NoNewline
    try { $hasAccount = (Read-Host '(Y/N)').Trim().ToUpper() } catch { $hasAccount = 'Y' }
  }

  if ($hasAccount -eq 'N') {
    Write-Host ''
    Write-Host '  No problem! Let''s create one.' -ForegroundColor Green
    Write-Host ''
    Write-Instruction @(
      'CREATING A GITHUB ACCOUNT:',
      '',
      '  1. A browser window will open to github.com/signup',
      '  2. Use your PERSONAL email (Gmail, Outlook, etc.)',
      '     Do NOT use your @microsoft.com email.',
      '  3. Choose a username you will remember',
      '  4. Follow the steps to verify your email',
      '  5. Come back here when you are done'
    )
    Prompt-Continue 'Press Enter to open GitHub signup in your browser...'
    Start-Process 'https://github.com/signup'

    Write-Host ''
    Write-Host '  Take your time setting up your account.' -ForegroundColor DarkGray
    Write-Host '  When you are done, come back to this window.' -ForegroundColor DarkGray
    Write-Host ''
    Prompt-Continue 'Press Enter when your GitHub account is ready...'
    Write-Ok 'Great! Moving on.'
  }

  # ══════════════════════════════════════════════════════════════════
  # STEP 3: Join the Microsoft GitHub Organization
  # ══════════════════════════════════════════════════════════════════
  Write-Step 3 'Joining the Microsoft GitHub organization'

  Write-Instruction @(
    'The tools you are installing live in Microsoft''s',
    'private GitHub. You need to link your personal GitHub',
    'account to Microsoft to get access.',
    '',
    'If you have ALREADY done this — just press Enter.',
    '',
    'If you have NOT — follow these steps:'
  )

  Write-Host '  HOW TO JOIN (takes ~2 minutes):' -ForegroundColor White
  Write-Host ''
  Write-Host '    1. Go to ' -ForegroundColor DarkGray -NoNewline
  Write-Host 'https://repos.opensource.microsoft.com/link' -ForegroundColor Cyan
  Write-Host '    2. Sign in with your ' -ForegroundColor DarkGray -NoNewline
  Write-Host '@microsoft.com' -ForegroundColor White -NoNewline
  Write-Host ' work account' -ForegroundColor DarkGray
  Write-Host '    3. It will ask you to link your ' -ForegroundColor DarkGray -NoNewline
  Write-Host 'personal GitHub' -ForegroundColor White -NoNewline
  Write-Host ' account' -ForegroundColor DarkGray
  Write-Host '    4. Authorize the connection when prompted' -ForegroundColor DarkGray
  Write-Host '    5. You should see a ' -ForegroundColor DarkGray -NoNewline
  Write-Host '"Successfully linked"' -ForegroundColor Green -NoNewline
  Write-Host ' message' -ForegroundColor DarkGray
  Write-Host ''

  $needsLink = $null
  while ($needsLink -ne 'Y' -and $needsLink -ne 'N') {
    Write-Host '  Do you need to link your account now? ' -ForegroundColor White -NoNewline
    try { $needsLink = (Read-Host '(Y/N)').Trim().ToUpper() } catch { $needsLink = 'N' }
  }

  if ($needsLink -eq 'Y') {
    Start-Process 'https://repos.opensource.microsoft.com/link'
    Write-Host ''
    Write-Host '  Complete the linking in your browser, then come back here.' -ForegroundColor DarkGray
    Write-Host ''
    Prompt-Continue 'Press Enter when you have linked your account...'
  }

  Write-Ok 'Account setup complete.'

  # ══════════════════════════════════════════════════════════════════
  # STEP 4: Sign in to GitHub
  # ══════════════════════════════════════════════════════════════════
  Write-Step 4 'Signing in to GitHub'

  $authOk = $false
  try {
    $null = & gh auth status 2>&1
    if ($LASTEXITCODE -eq 0) { $authOk = $true }
  } catch {}

  if ($authOk) {
    Write-Ok 'Already signed in to GitHub!'
  } else {
    Write-Instruction @(
      'A browser window will open for you to sign in.',
      '',
      'IMPORTANT: Sign in with your PERSONAL GitHub',
      'account — the one you just linked to Microsoft.',
      '',
      'Do NOT use an account ending in _microsoft.',
      '(If your browser auto-fills the wrong account,',
      ' click "Use a different account".)'
    )

    Prompt-Continue 'Press Enter to open the sign-in page...'

    & gh auth login --web --git-protocol https -s read:org,repo,read:packages
    if ($LASTEXITCODE -ne 0) {
      Write-Fail 'Sign-in did not complete.'
      Write-Host ''
      Write-Host '  No worries — just run this setup again and it will' -ForegroundColor DarkGray
      Write-Host '  pick up where you left off.' -ForegroundColor DarkGray
      return 1
    }
    Write-Ok 'Signed in successfully!'
  }

  # Verify Microsoft org membership.
  $orgCheck = & gh api user/memberships/orgs/microsoft --jq '.state' 2>$null
  if ($LASTEXITCODE -ne 0 -or $orgCheck -ne 'active') {
    Write-Host ''
    Write-Warn 'It looks like your account may not be linked to the Microsoft org yet.'
    Write-Host ''
    Write-Host '  This is required to access the tools. If you skipped Step 3,' -ForegroundColor DarkGray
    Write-Host '  go to ' -ForegroundColor DarkGray -NoNewline
    Write-Host 'https://repos.opensource.microsoft.com/link' -ForegroundColor Cyan -NoNewline
    Write-Host ' now.' -ForegroundColor DarkGray
    Write-Host ''

    $continueAnyway = $null
    while ($continueAnyway -ne 'Y' -and $continueAnyway -ne 'N') {
      Write-Host '  Try to continue anyway? ' -ForegroundColor White -NoNewline
      try { $continueAnyway = (Read-Host '(Y/N)').Trim().ToUpper() } catch { $continueAnyway = 'N' }
    }
    if ($continueAnyway -ne 'Y') {
      Write-Info 'No problem. Link your account, then run this setup again.'
      return 1
    }
  } else {
    Write-Ok 'Microsoft org membership confirmed.'
  }

  # ══════════════════════════════════════════════════════════════════
  # STEP 5: Choose a Toolkit
  # ══════════════════════════════════════════════════════════════════
  Write-Step 5 'Choosing which toolkit to install'

  $repoOwner = $null
  $repoName  = $null

  if ($Repo) {
    # Pre-selected via env var or parameter.
    foreach ($entry in $Catalog.Values) {
      if ($entry.Key -eq $Repo -or $entry.Name -eq $Repo -or "$($entry.Owner)/$($entry.Name)" -eq $Repo) {
        $repoOwner = $entry.Owner
        $repoName  = $entry.Name
        break
      }
    }
    if (-not $repoOwner) {
      if ($Repo -match '^([^/]+)/(.+)$') {
        $repoOwner = $Matches[1]
        $repoName  = $Matches[2]
      } else {
        Write-Fail "Unknown toolkit '$Repo'."
        return 1
      }
    }
    Write-Ok "Pre-selected: $repoOwner/$repoName"
  } else {
    Write-Host '  Which toolkit would you like to install?' -ForegroundColor White
    Write-Host ''

    foreach ($num in ($Catalog.Keys | Sort-Object)) {
      $r = $Catalog[$num]
      Write-Host "    $num) " -ForegroundColor White -NoNewline
      Write-Host "$($r.Key)" -ForegroundColor Cyan -NoNewline
      Write-Host " — $($r.Description)" -ForegroundColor DarkGray
    }
    Write-Host ''

    $choice = $null
    while (-not $choice -or -not $Catalog.ContainsKey([int]$choice)) {
      Write-Host '  Enter a number (1, 2, or 3): ' -ForegroundColor White -NoNewline
      try {
        $raw = Read-Host
        if ($raw -match '^\d+$') { $choice = [int]$raw }
      } catch {}
      if ($choice -and -not $Catalog.ContainsKey($choice)) {
        Write-Host "  That's not a valid option. Try again." -ForegroundColor Yellow
        $choice = $null
      }
    }

    $selected  = $Catalog[$choice]
    $repoOwner = $selected.Owner
    $repoName  = $selected.Name
  }

  $repoSlug = "$repoOwner/$repoName"
  Write-Host ''
  Write-Ok "You chose: $repoName"

  # ══════════════════════════════════════════════════════════════════
  # STEP 6: Choose install directory
  # ══════════════════════════════════════════════════════════════════
  Write-Step 6 'Choosing where to install'

  $defaultDir = Join-Path $HOME $repoName

  if (-not $Dir) {
    Write-Host "  We will install to: " -ForegroundColor DarkGray -NoNewline
    Write-Host "$defaultDir" -ForegroundColor White
    Write-Host ''
    Write-Host '  Press Enter to accept, or type a different folder path.' -ForegroundColor DarkGray
    Write-Host ''
    $requested = $null
    try { $requested = Read-Host '  Install location' } catch {}
    if ([string]::IsNullOrWhiteSpace($requested)) {
      $Dir = $defaultDir
    } else {
      $Dir = $requested.Trim()
    }
  }

  # Normalize drive-relative paths (e.g. c:temp → c:\temp).
  if ($Dir -match '^[A-Za-z]:[^\\/]') {
    $Dir = $Dir.Substring(0, 2) + '\' + $Dir.Substring(2)
  }
  $Dir = [System.IO.Path]::GetFullPath($Dir)

  # Block cloud-synced paths.
  if (Test-CloudSyncedPath $Dir) {
    Write-Host ''
    Write-Fail 'That folder is inside a cloud-synced location (OneDrive, Dropbox, etc.).'
    Write-Host ''
    Write-Host '  This can accidentally sync passwords to the cloud.' -ForegroundColor Yellow
    Write-Host "  Please choose a different folder, like: $defaultDir" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Run this setup again and pick a different location.' -ForegroundColor DarkGray
    return 1
  }

  $dirExists  = Test-Path $Dir
  $dirIsEmpty = $false
  if ($dirExists) {
    $dirIsEmpty = -not (Get-ChildItem -Path $Dir -Force | Select-Object -First 1)
  }

  if ($dirExists -and -not $dirIsEmpty -and -not $Force) {
    Write-Warn "That folder already exists and has files in it: $Dir"
    Write-Host ''
    $overwrite = $null
    while ($overwrite -ne 'Y' -and $overwrite -ne 'N') {
      Write-Host '  Delete it and start fresh? ' -ForegroundColor White -NoNewline
      try { $overwrite = (Read-Host '(Y/N)').Trim().ToUpper() } catch { $overwrite = 'N' }
    }
    if ($overwrite -eq 'Y') {
      $Force = [switch]::Present
    } else {
      Write-Info 'No problem. Run setup again and choose a different folder.'
      return 1
    }
  }

  Write-Ok "Installing to: $Dir"

  # ══════════════════════════════════════════════════════════════════
  # STEP 7: Download and run repo bootstrap
  # ══════════════════════════════════════════════════════════════════
  Write-Step 7 "Downloading $repoName"

  if ((Test-Path $Dir) -and $Force) {
    $hasContent = [bool](Get-ChildItem -Path $Dir -Force | Select-Object -First 1)
    if ($hasContent) {
      Write-Info 'Removing existing folder...'
      Remove-Item -Path $Dir -Recurse -Force
    }
  }

  $parent = Split-Path -Parent $Dir
  if ($parent -and -not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  Write-Host '  Downloading... this may take a minute.' -ForegroundColor DarkGray
  & gh repo clone $repoSlug $Dir -- --branch $Ref --depth 1
  if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Fail "Could not download $repoName."
    Write-Host ''
    Write-Host '  This usually means one of:' -ForegroundColor Yellow
    Write-Host '    - Your GitHub account is not linked to the Microsoft org' -ForegroundColor Yellow
    Write-Host '    - You don''t have access to this specific repo' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  To fix:' -ForegroundColor DarkGray
    Write-Host '    1. Go to https://repos.opensource.microsoft.com/link' -ForegroundColor DarkGray
    Write-Host '    2. Make sure your account is linked' -ForegroundColor DarkGray
    Write-Host '    3. Run this setup again' -ForegroundColor DarkGray
    return 1
  }

  Write-Ok "Downloaded $repoName!"

  # ── Discover and run the repo's bootstrap script ────────────────
  Write-Host ''
  Write-Host '  Now running the toolkit''s own setup...' -ForegroundColor DarkGray
  Write-Host '  (This may install additional tools and ask more questions.)' -ForegroundColor DarkGray
  Write-Host ''

  Set-Location $Dir

  # 1. Check for .setup.json convention file.
  $setupJson = Join-Path $Dir '.setup.json'
  $bootstrapScript = $null

  if (Test-Path $setupJson) {
    try {
      $setup = Get-Content $setupJson -Raw | ConvertFrom-Json
      $winBoot = $setup.bootstrap.windows
      if ($winBoot) {
        $candidate = Join-Path $Dir $winBoot
        if (Test-Path $candidate) {
          $bootstrapScript = $candidate
        }
      }
    } catch {}
  }

  # 2. Fall back to conventional paths.
  if (-not $bootstrapScript) {
    foreach ($p in @(
      'scripts/bootstrap.ps1', 'scripts/setup.ps1', 'scripts/install.ps1',
      'bootstrap.ps1', 'setup.ps1'
    )) {
      $candidate = Join-Path $Dir $p
      if (Test-Path $candidate) {
        $bootstrapScript = $candidate
        break
      }
    }
  }

  if (-not $bootstrapScript) {
    Write-Host ''
    Write-Ok "Download complete! $repoName is ready at:"
    Write-Host "  $Dir" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Open that folder to get started.' -ForegroundColor DarkGray
    return 0
  }

  Set-ExecutionPolicy -Scope Process Bypass -Force -ErrorAction SilentlyContinue
  & $bootstrapScript

  $rc = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
  if ($rc -ne 0) {
    Write-Fail "The toolkit setup had an issue (code $rc)."
    Write-Host "  You can try running it again: $bootstrapScript" -ForegroundColor DarkGray
    return $rc
  }

  # ── Done! ───────────────────────────────────────────────────────
  Write-Host ''
  Write-Host '  ╔══════════════════════════════════════════════════════════╗' -ForegroundColor Green
  Write-Host '  ║                                                          ║' -ForegroundColor Green
  Write-Host '  ║               ✔  Setup Complete!                         ║' -ForegroundColor Green
  Write-Host '  ║                                                          ║' -ForegroundColor Green
  Write-Host '  ╚══════════════════════════════════════════════════════════╝' -ForegroundColor Green
  Write-Host ''
  Write-Host "  $repoName is installed at: " -ForegroundColor White -NoNewline
  Write-Host "$Dir" -ForegroundColor Cyan
  Write-Host ''
  Write-Host '  To open it in VS Code, run:' -ForegroundColor DarkGray
  Write-Host "    code `"$Dir`"" -ForegroundColor White
  Write-Host ''
  return 0
}

# ── Entry point ─────────────────────────────────────────────────────
Install-DevSetup @args
