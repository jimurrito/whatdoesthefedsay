<#
.SYNOPSIS
    Fetches the current Federal Reserve interest rate and commits it to a GitHub repository.

.DESCRIPTION
    This script scrapes the Federal Reserve's H.15 release page to retrieve the latest
    effective federal funds rate and its effective date. It then commits that data as a
    JSON payload to a specified file in a GitHub repository using the GitHub Git Data API
    (blob → tree → commit → ref update), effectively performing a headless git commit
    without requiring a local clone.

    A random seed is generated per run and included in both the payload and commit message
    to serve as a unique run identifier/nonce.

.PARAMETER TokenPath
    Path to a plain-text file containing a GitHub Personal Access Token (PAT).
    The token must have 'Contents' read/write permissions on the target repository.

.PARAMETER Path
    The repository-relative file path to write the rate data to.
    Defaults to 'rate.html'. Despite the .html extension, the file contains JSON.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    None. Writes status messages to the host and pushes a commit to GitHub.

.EXAMPLE
    .\Update-FedRate.ps1 -TokenPath "C:\secrets\github_token.txt"

    Fetches the latest Fed rate and commits it to 'rate.html' on the main branch.

.EXAMPLE
    .\Update-FedRate.ps1 -TokenPath "C:\secrets\github_token.txt" -Path "data/rate.json"

    Same as above, but commits the payload to 'data/rate.json' instead.

.NOTES
    Author   : jimurrito
    Repo     : https://github.com/jimurrito/whatdoesthefedsay
    API Ref  : https://docs.github.com/en/rest/git
    Data Src : https://www.federalreserve.gov/releases/h15/

    - Requires PowerShell 5.1 or later.
    - The GitHub API version targeted is 2022-11-28.
    - The script will hard-stop if the token file is not found (ErrorAction Stop).

.LINK
    https://www.federalreserve.gov/releases/h15/

.LINK
    https://docs.github.com/en/rest/git/commits
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$TokenPath,   # GitHub Personal Access Token
    [string]$Path  = "rate.html"
)

# Kills script if a func fails
$ErrorActionPreference = "Stop"

# ── 0. Get Token from file ───────────────────────────────────────────────────
$Token = Get-Content -Path $TokenPath -ErrorAction stop

# ── 1. Fetch the Fed's H.15 release page ──────────────────────────────────────
$fedUrl = "https://www.federalreserve.gov/releases/h15/"
($date, $rate) = (
    (Invoke-WebRequest $fedUrl).Content -split "`n" -match "col5"
)[0..1]

# ── 2. Parse date and rate out of the raw HTML ────────────────────────────────
$date = (($date -split ">")[1..3] -split "<")[0, 2, 4] -join "-"
$rate = ($rate -split "&nbsp;")[1]

write-host ("Effective Rate {0}% as of {1}" -f $rate, $date)

# ── 3. Generate a random seed (used as a nonce/identifier) ───────────────────
$seed = Get-Random -Minimum 100000000 -Maximum 999999999
write-host ("Seed for commit {0}" -f $seed)

# ── 4. Build the JSON payload that will be committed ─────────────────────────
$payload = @{
    rate   = $rate
    date   = $date
    seed   = $seed
    source = "https://www.federalreserve.gov/releases/h15/"
} | ConvertTo-Json

# ── 5. Set GitHub API request headers ────────────────────────────────────────
$headers = @{
    Authorization        = "Bearer $Token"
    "X-GitHub-Api-Version" = "2022-11-28"
    "User-Agent"         = "WhatDoesTheFedSay"
    "Content-Type"       = "application/json"
}

$branch  = "main"
$apiBase = "https://api.github.com/repos/jimurrito/whatdoesthefedsay"

# ── 6. Get the current HEAD commit SHA of the main branch ────────────────────
$headSha = (
    (Invoke-WebRequest -Uri "$apiBase/branches/$branch" -Headers $headers).Content |
    ConvertFrom-Json
).commit.sha

# ── 7. Create a new blob containing the JSON payload ─────────────────────────
$blobBody = @{
    content  = [System.Convert]::ToBase64String(
                   [System.Text.Encoding]::UTF8.GetBytes($payload))
    encoding = "base64"
} | ConvertTo-Json

$blobSha = (
    (Invoke-WebRequest -Uri "$apiBase/git/blobs" -Headers $headers `
                       -Body $blobBody -Method Post).Content |
    ConvertFrom-Json
).sha

# ── 8. Create a new tree pointing at that blob ───────────────────────────────
$treeBody = @{
    base_tree = $headSha
    tree      = @(
        @{
            path = $Path          # "rate.html" (despite containing JSON)
            mode = "100644"
            type = "blob"
            sha  = $blobSha
        }
    )
} | ConvertTo-Json

$treeSha = (
    (Invoke-WebRequest -Uri "$apiBase/git/trees" -Headers $headers `
                       -Body $treeBody -Method Post).Content |
    ConvertFrom-Json
).sha

# ── 9. Create a commit on top of that tree ───────────────────────────────────
$commitBody = @{
    message = "$date - $seed"
    parents = @($headSha)
    tree    = $treeSha
} | ConvertTo-Json

$commitSha = (
    (Invoke-WebRequest -Uri "$apiBase/git/commits" -Headers $headers `
                       -Body $commitBody -Method Post).Content |
    ConvertFrom-Json
).sha

# ── 10. Fast-forward the branch ref to the new commit ────────────────────────
$refBody = @{ sha = $commitSha } | ConvertTo-Json

Invoke-WebRequest -Uri "$apiBase/git/refs/heads/$branch" -Headers $headers `
                  -Body $refBody -Method Patch | Out-Null
