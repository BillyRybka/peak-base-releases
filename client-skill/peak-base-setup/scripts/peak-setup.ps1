# Peak Base setup helper for Windows (Windows PowerShell 5.1 or later).
#
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File peak-setup.ps1 <command> [args]
#
# Secrets (the Hostinger token, the server's root password, the password
# recovery key) live in Windows Credential Manager under "Peak Base Setup/<name>".
# They are typed into a private box on screen or generated here, and they are
# never printed: commands report "saved", "made" or "ok", and Hostinger answers
# are printed with every stored secret blanked out.

param(
  [Parameter(Position = 0)] [string] $Command = "help",
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest = @()
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Api = "https://developers.hostinger.com"
$Compose = "https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml"
$Download = "https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Windows.exe"
$Project = "peak-base"
$Prefix = "Peak Base Setup/"

function Arg([int] $i, [string] $what) {
  if ($Rest.Count -le $i -or [string]::IsNullOrWhiteSpace($Rest[$i])) { throw "missing $what" }
  return $Rest[$i]
}
function Out-Json($o) { $o | ConvertTo-Json -Depth 12 -Compress }

# ---- Credential Manager ------------------------------------------------------

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class PeakCred {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct CREDENTIAL {
    public int Flags; public int Type; public string TargetName; public string Comment;
    public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
    public int CredentialBlobSize; public IntPtr CredentialBlob; public int Persist;
    public int AttributeCount; public IntPtr Attributes; public string TargetAlias; public string UserName;
  }
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CredWriteW(ref CREDENTIAL c, int flags);
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CredReadW(string target, int type, int flags, out IntPtr c);
  [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  static extern bool CredDeleteW(string target, int type, int flags);
  [DllImport("advapi32.dll")] static extern void CredFree(IntPtr p);
  public static void Write(string target, string secret) {
    byte[] b = Encoding.Unicode.GetBytes(secret);
    CREDENTIAL c = new CREDENTIAL();
    c.Type = 1; c.TargetName = target; c.Persist = 2; c.UserName = "Peak Base";
    c.CredentialBlobSize = b.Length; c.CredentialBlob = Marshal.AllocHGlobal(b.Length);
    Marshal.Copy(b, 0, c.CredentialBlob, b.Length);
    try { if (!CredWriteW(ref c, 0)) throw new Exception("CredWrite failed: " + Marshal.GetLastWin32Error()); }
    finally { Marshal.FreeHGlobal(c.CredentialBlob); }
  }
  public static string Read(string target) {
    IntPtr p;
    if (!CredReadW(target, 1, 0, out p)) return null;
    try {
      CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(p, typeof(CREDENTIAL));
      if (c.CredentialBlobSize == 0) return "";
      byte[] b = new byte[c.CredentialBlobSize];
      Marshal.Copy(c.CredentialBlob, b, 0, b.Length);
      return Encoding.Unicode.GetString(b);
    } finally { CredFree(p); }
  }
  public static bool Delete(string target) { return CredDeleteW(target, 1, 0); }
}
"@

function Get-Secret([string] $name) { [PeakCred]::Read($Prefix + $name) }
function Set-Secret([string] $name, [string] $value) { [PeakCred]::Write($Prefix + $name, $value) }
function Need-Secret([string] $name) {
  $v = Get-Secret $name
  if (-not $v) { throw "no saved secret named $name (run ask-secret or make-secret first)" }
  return $v
}

# Letters and digits only, with at least one of each kind (Hostinger's root
# password rule: 12+ characters, upper, lower, number, not a known leaked one).
function New-RandomSecret([int] $length) {
  $chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789".ToCharArray()
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  while ($true) {
    $bytes = New-Object byte[] $length
    $rng.GetBytes($bytes)
    $s = -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
    if ($s -cmatch "[A-Z]" -and $s -cmatch "[a-z]" -and $s -match "[0-9]") { return $s }
  }
}

# ---- The private box ---------------------------------------------------------

function Show-SecretBox([string] $title, [string] $message, [bool] $confirm, [int] $minLength) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()
  $form = New-Object System.Windows.Forms.Form
  $form.Text = $title
  $form.StartPosition = "CenterScreen"
  $form.TopMost = $true
  $form.FormBorderStyle = "FixedDialog"
  $form.MaximizeBox = $false
  $form.MinimizeBox = $false
  $form.Font = New-Object System.Drawing.Font("Segoe UI", 10)
  $form.ClientSize = New-Object System.Drawing.Size(460, $(if ($confirm) { 250 } else { 200 }))

  $label = New-Object System.Windows.Forms.Label
  $label.Text = $message
  $label.Location = New-Object System.Drawing.Point(16, 14)
  $label.Size = New-Object System.Drawing.Size(428, 60)
  $form.Controls.Add($label)

  $box1 = New-Object System.Windows.Forms.TextBox
  $box1.UseSystemPasswordChar = $true
  $box1.Location = New-Object System.Drawing.Point(16, 80)
  $box1.Size = New-Object System.Drawing.Size(428, 26)
  $form.Controls.Add($box1)

  $y = 116
  $box2 = $null
  if ($confirm) {
    $l2 = New-Object System.Windows.Forms.Label
    $l2.Text = "Type it again:"
    $l2.Location = New-Object System.Drawing.Point(16, $y)
    $l2.Size = New-Object System.Drawing.Size(428, 22)
    $form.Controls.Add($l2)
    $box2 = New-Object System.Windows.Forms.TextBox
    $box2.UseSystemPasswordChar = $true
    $box2.Location = New-Object System.Drawing.Point(16, ($y + 24))
    $box2.Size = New-Object System.Drawing.Size(428, 26)
    $form.Controls.Add($box2)
    $y += 60
  }

  $show = New-Object System.Windows.Forms.CheckBox
  $show.Text = "Show what I typed"
  $show.Location = New-Object System.Drawing.Point(16, $y)
  $show.Size = New-Object System.Drawing.Size(220, 24)
  $show.Add_CheckedChanged({
    $box1.UseSystemPasswordChar = -not $show.Checked
    if ($box2) { $box2.UseSystemPasswordChar = -not $show.Checked }
  })
  $form.Controls.Add($show)

  $err = New-Object System.Windows.Forms.Label
  $err.ForeColor = [System.Drawing.Color]::Firebrick
  $err.Location = New-Object System.Drawing.Point(16, ($y + 28))
  $err.Size = New-Object System.Drawing.Size(260, 40)
  $form.Controls.Add($err)

  $ok = New-Object System.Windows.Forms.Button
  $ok.Text = "Save"
  $ok.Location = New-Object System.Drawing.Point(288, ($y + 32))
  $ok.Size = New-Object System.Drawing.Size(76, 30)
  $form.Controls.Add($ok)
  $cancel = New-Object System.Windows.Forms.Button
  $cancel.Text = "Cancel"
  $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $cancel.Location = New-Object System.Drawing.Point(368, ($y + 32))
  $cancel.Size = New-Object System.Drawing.Size(76, 30)
  $form.Controls.Add($cancel)
  $form.AcceptButton = $ok
  $form.CancelButton = $cancel

  $ok.Add_Click({
    $v = $box1.Text.Trim()
    if ($v.Length -lt $minLength) { $err.Text = "That needs at least $minLength characters."; return }
    if ($box2 -and $box2.Text.Trim() -ne $v) { $err.Text = "The two don't match. Try again."; return }
    $form.Tag = $v
    $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.Close()
  })
  # Claude may start this from a hidden console, and Windows then hides the
  # first window the process opens. Show the box ourselves once it has loaded.
  $reveal = New-Object System.Windows.Forms.Timer
  $reveal.Interval = 250
  $reveal.Add_Tick({ $reveal.Stop(); $form.Visible = $true; $form.WindowState = "Normal"; $form.Activate(); [void] $box1.Focus() })
  $form.Add_Load({ $reveal.Start() })
  $result = $form.ShowDialog()
  $value = $form.Tag
  $form.Dispose()
  if ($result -ne [System.Windows.Forms.DialogResult]::OK -or -not $value) { return $null }
  return [string] $value
}

# ---- Hostinger ---------------------------------------------------------------

function Hide-Secrets([string] $text) {
  foreach ($n in @("hostinger-token", "server-root", "recovery-key", "resend-api-key")) {
    $v = Get-Secret $n
    if ($v) { $text = $text.Replace($v, "[hidden]") }
  }
  return $text
}

# One Hostinger API call, retried through rate limits, maintenance and hiccups.
# Returns the parsed answer; throws with Hostinger's own message on a refusal.
function Invoke-Hostinger([string] $method, [string] $path, $body, [int] $tries = 12) {
  $token = Need-Secret "hostinger-token"
  $headers = @{ Authorization = "Bearer $token"; Accept = "application/json" }
  $json = $null
  if ($null -ne $body) { $json = $body | ConvertTo-Json -Depth 12 -Compress }
  for ($i = 1; $i -le $tries; $i++) {
    try {
      $req = @{ Uri = "$Api$path"; Method = $method; Headers = $headers; UseBasicParsing = $true; TimeoutSec = 60 }
      if ($json) { $req.Body = [Text.Encoding]::UTF8.GetBytes($json); $req.ContentType = "application/json" }
      $r = Invoke-WebRequest @req
      if (-not $r.Content) { return $null }
      return $r.Content | ConvertFrom-Json
    } catch {
      $status = 0; $text = $_.Exception.Message; $retryAfter = 0
      $resp = $_.Exception.Response
      if ($resp) {
        $status = [int] $resp.StatusCode
        try {
          $reader = New-Object IO.StreamReader($resp.GetResponseStream())
          $text = $reader.ReadToEnd()
        } catch {}
        try { $retryAfter = [int] $resp.Headers["Retry-After"] } catch {}
      }
      $text = Hide-Secrets $text
      $passing = ($status -eq 0) -or ($status -eq 429) -or ($status -ge 500) -or ($text -match "maintenance|temporarily|try again")
      if (-not $passing -or $i -eq $tries) { throw "Hostinger answered $status on $method $path`: $text" }
      $wait = [Math]::Max($retryAfter, [Math]::Min(60, 10 * $i))
      [Console]::Error.WriteLine("Hostinger is busy ($status). Trying again in $wait seconds ($i of $tries).")
      Start-Sleep -Seconds $wait
    }
  }
}

function Get-Items($answer) {
  if ($null -eq $answer) { return @() }
  if ($answer.PSObject.Properties.Name -contains "data") { return @($answer.data) }
  return @($answer)
}

function Find-DockerTemplate {
  $t = Get-Items (Invoke-Hostinger GET "/api/vps/v1/templates" $null) |
    Where-Object { $_.name -match "Ubuntu" -and $_.name -match "Docker" } |
    Sort-Object name -Descending | Select-Object -First 1
  if (-not $t) { throw "Hostinger lists no Ubuntu with Docker template" }
  return $t
}

function Get-Server([string] $id) { Invoke-Hostinger GET "/api/vps/v1/virtual-machines/$id" $null }

function Wait-Server([string] $id, [int] $minutes) {
  $until = (Get-Date).AddMinutes($minutes)
  while ((Get-Date) -lt $until) {
    $vm = Get-Server $id
    if ($vm.state -eq "running" -and $vm.actions_lock -ne "locked") { return $vm }
    [Console]::Error.WriteLine("Server is $($vm.state) ($($vm.actions_lock)). Checking again in 20 seconds.")
    Start-Sleep -Seconds 20
  }
  throw "the server was still not ready after $minutes minutes"
}

# ---- Commands ----------------------------------------------------------------

switch ($Command) {
  "ask-secret" {
    # ask-secret <name> <title> <message> [minLength] [confirm]
    $name = Arg 0 "name"; $title = Arg 1 "title"; $message = Arg 2 "message"
    $min = 8; if ($Rest.Count -gt 3) { $min = [int] $Rest[3] }
    $confirm = ($Rest.Count -gt 4 -and $Rest[4] -eq "confirm")
    $v = Show-SecretBox $title $message $confirm $min
    if (-not $v) { "cancelled"; break }
    Set-Secret $name $v
    "saved"
  }
  "has-secret" { if (Get-Secret (Arg 0 "name")) { "yes" } else { "no" } }
  "make-secret" {
    $name = Arg 0 "name"; $len = 40; if ($Rest.Count -gt 1) { $len = [int] $Rest[1] }
    if (Get-Secret $name) { "kept (already saved)" } else { Set-Secret $name (New-RandomSecret $len); "made" }
  }
  "secret-matches" {
    # secret-matches <name> <sha256 hex>: compares without showing the secret (tests).
    $v = Need-Secret (Arg 0 "name")
    $h = -join ([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($v)) | ForEach-Object { $_.ToString("x2") })
    if ($h -eq (Arg 1 "sha256").ToLower()) { "match" } else { "different" }
  }
  "forget-secret" { if ([PeakCred]::Delete($Prefix + (Arg 0 "name"))) { "forgotten" } else { "none saved" } }

  "check-token" {
    $vms = Get-Items (Invoke-Hostinger GET "/api/vps/v1/virtual-machines" $null)
    "ok: the token works and sees $($vms.Count) server(s)"
  }
  "servers" {
    $vms = Get-Items (Invoke-Hostinger GET "/api/vps/v1/virtual-machines" $null)
    Out-Json @($vms | ForEach-Object {
      [ordered]@{
        id = $_.id; state = $_.state; actions_lock = $_.actions_lock; plan = $_.plan
        hostname = $_.hostname; ipv4 = @($_.ipv4 | ForEach-Object { $_.address })
        template = $(if ($_.template) { $_.template.name } else { $null })
        data_center_id = $_.data_center_id; firewall_group_id = $_.firewall_group_id; created_at = $_.created_at
      }
    })
  }
  "options" {
    $dcs = Get-Items (Invoke-Hostinger GET "/api/vps/v1/data-centers" $null)
    $t = Find-DockerTemplate
    Out-Json ([ordered]@{
      docker_template = [ordered]@{ id = $t.id; name = $t.name }
      this_computer_time_zone = [TimeZoneInfo]::Local.Id
      data_centers = @($dcs | ForEach-Object { [ordered]@{ id = $_.id; name = $_.name; city = $_.city; location = $_.location; continent = $_.continent } })
    })
  }
  "setup-server" {
    # setup-server <serverId> <dataCenterId> [templateId]  (a new server in state "initial")
    $id = Arg 0 "server id"; $dc = [int] (Arg 1 "data center id")
    $tid = $(if ($Rest.Count -gt 2) { [int] $Rest[2] } else { (Find-DockerTemplate).id })
    $vm = Get-Server $id
    if ($vm.state -ne "initial") { throw "this server is already set up (state $($vm.state)); use set-root-password, or recreate-server to erase it" }
    if (-not (Get-Secret "server-root")) { Set-Secret "server-root" (New-RandomSecret 24) }
    $body = [ordered]@{
      template_id = $tid; data_center_id = $dc; password = (Need-Secret "server-root")
      install_monarx = $false; enable_backups = $true
    }
    $a = Invoke-Hostinger POST "/api/vps/v1/virtual-machines/$id/setup" $body 30
    "setup started: " + (Hide-Secrets (Out-Json $a))
  }
  "recreate-server" {
    # recreate-server <serverId> erase-everything [templateId]  (ERASES the server)
    $id = Arg 0 "server id"
    if ((Arg 1 "the words erase-everything") -ne "erase-everything") { throw "say erase-everything to confirm" }
    $tid = $(if ($Rest.Count -gt 2) { [int] $Rest[2] } else { (Find-DockerTemplate).id })
    if (-not (Get-Secret "server-root")) { Set-Secret "server-root" (New-RandomSecret 24) }
    $body = [ordered]@{ template_id = $tid; password = (Need-Secret "server-root") }
    $a = Invoke-Hostinger POST "/api/vps/v1/virtual-machines/$id/recreate" $body 30
    "recreate started: " + (Hide-Secrets (Out-Json $a))
  }
  "set-root-password" {
    $id = Arg 0 "server id"
    if (-not (Get-Secret "server-root")) { Set-Secret "server-root" (New-RandomSecret 24) }
    $a = Invoke-Hostinger PUT "/api/vps/v1/virtual-machines/$id/root-password" ([ordered]@{ password = (Need-Secret "server-root") })
    "root password replaced and saved in Credential Manager"
  }
  "wait-server" {
    $id = Arg 0 "server id"; $m = 20; if ($Rest.Count -gt 1) { $m = [int] $Rest[1] }
    $vm = Wait-Server $id $m
    "ready: $($vm.hostname) " + (Out-Json @($vm.ipv4 | ForEach-Object { $_.address }))
  }
  "deploy" {
    # deploy <serverId> <address>  (creates or replaces the peak-base project)
    $id = Arg 0 "server id"; $address = (Arg 1 "address") -replace "^https?://", "" -replace "/+$", ""
    if (-not (Get-Secret "recovery-key")) { Set-Secret "recovery-key" (New-RandomSecret 48) }
    $env = @(
      "DOMAIN=$address",
      "MCP_SERVER_TITLE=Business Brain",
      "PASSWORD_RECOVERY_KEY=$(Need-Secret 'recovery-key')"
    )
    $mailFile = Join-Path $Here "mail.key"
    $mail = "off"
    if (Test-Path $mailFile) {
      $m = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Get-Content $mailFile -Raw).Trim())) | ConvertFrom-Json
      if ($m.key -and $m.from) { $env += "RESEND_API_KEY=$($m.key)"; $env += "EMAIL_FROM=`"$($m.from)`""; $mail = "on" }
    }
    $body = [ordered]@{ project_name = $Project; content = $Compose; environment = ($env -join "`n") }
    $a = Invoke-Hostinger POST "/api/vps/v1/virtual-machines/$id/docker" $body 20
    "deploy started (password reset email: $mail): " + (Hide-Secrets (Out-Json $a))
  }
  "update-server" {
    # update-server <serverId>: pull the newest Peak Base server and restart it.
    $id = Arg 0 "server id"
    $a = Invoke-Hostinger POST "/api/vps/v1/virtual-machines/$id/docker/$Project/update" $null 20
    "update started: " + (Hide-Secrets (Out-Json $a))
  }
  "containers" {
    $id = Arg 0 "server id"
    $c = Get-Items (Invoke-Hostinger GET "/api/vps/v1/virtual-machines/$id/docker/$Project/containers" $null)
    Out-Json @($c | ForEach-Object { [ordered]@{ name = $_.name; state = $_.state; health = $_.health; status = $_.status } })
  }
  "projects" {
    $id = Arg 0 "server id"
    Out-Json @(Get-Items (Invoke-Hostinger GET "/api/vps/v1/virtual-machines/$id/docker" $null) | ForEach-Object { [ordered]@{ name = $_.name; state = $_.state; status = $_.status } })
  }
  "logs" {
    $id = Arg 0 "server id"
    Hide-Secrets (Out-Json (Invoke-Hostinger GET "/api/vps/v1/virtual-machines/$id/docker/$Project/logs" $null))
  }
  "firewall" {
    # firewall <serverId>: with no firewall there is nothing to do; with one,
    # make sure it lets in 22, 80 and 443, then sync it.
    $id = Arg 0 "server id"
    $vm = Get-Server $id
    if (-not $vm.firewall_group_id) { "ok: no firewall on this server"; break }
    $fw = Invoke-Hostinger GET "/api/vps/v1/firewall/$($vm.firewall_group_id)" $null
    $added = @()
    foreach ($port in @("22", "80", "443")) {
      $has = @($fw.rules | Where-Object { $_.action -ne "drop" -and ($_.port -eq $port -or $_.port -eq "any") -and ($_.protocol -in @("TCP", "any", "SSH", "HTTP", "HTTPS")) }).Count -gt 0
      if (-not $has) {
        Invoke-Hostinger POST "/api/vps/v1/firewall/$($vm.firewall_group_id)/rules" ([ordered]@{ protocol = "TCP"; port = $port; source = "any"; source_detail = "any" }) | Out-Null
        $added += $port
      }
    }
    Invoke-Hostinger POST "/api/vps/v1/firewall/$($vm.firewall_group_id)/sync/$id" $null | Out-Null
    "ok: firewall $($vm.firewall_group_id) allows 22, 80, 443 (added: $($added -join ', '))"
  }
  "health" {
    $address = (Arg 0 "address") -replace "^https?://", "" -replace "/+$", ""
    $m = 15; if ($Rest.Count -gt 1) { $m = [int] $Rest[1] }
    $until = (Get-Date).AddMinutes($m)
    while ($true) {
      try {
        $r = Invoke-WebRequest -Uri "https://$address/health" -UseBasicParsing -TimeoutSec 20
        "ok: " + $r.Content; break
      } catch {
        if ((Get-Date) -gt $until) { throw "https://$address/health still does not answer after $m minutes: $($_.Exception.Message)" }
        [Console]::Error.WriteLine("Not answering yet (the secure connection can take a few minutes). Checking again in 20 seconds.")
        Start-Sleep -Seconds 20
      }
    }
  }

  "install-app" {
    $file = Join-Path ([Environment]::GetFolderPath("UserProfile")) "Downloads\PeakBase-Windows.exe"
    Invoke-WebRequest -Uri $Download -OutFile $file -UseBasicParsing
    $size = [Math]::Round((Get-Item $file).Length / 1MB, 1)
    $p = Start-Process -FilePath $file -ArgumentList "/S" -PassThru -Wait
    $exe = Get-ChildItem (Join-Path $env:LOCALAPPDATA "Peak Base") -Filter *.exe -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne "uninstall.exe" } | Select-Object -First 1
    if (-not $exe) { throw "the installer finished (exit $($p.ExitCode)) but Peak Base is not in $env:LOCALAPPDATA\Peak Base" }
    Start-Process -FilePath $exe.FullName
    "installed and opened: $($exe.FullName) version $($exe.VersionInfo.FileVersion) (downloaded $size MB)"
  }
  "open-connect" {
    $address = (Arg 0 "address") -replace "^https?://", "" -replace "/+$", ""
    Start-Process "https://$address/open/connect"
    "opened https://$address/open/connect"
  }
  "open-folder" {
    # open-folder <folder> [skills]: Peak Base asks, then opens and syncs it.
    $folder = (Resolve-Path (Arg 0 "folder")).Path
    $q = "path=" + [Uri]::EscapeDataString($folder)
    if ($Rest.Count -gt 1 -and $Rest[1] -eq "skills") { $q += "&skills=1" }
    Start-Process "peakbase://open-folder?$q"
    "asked Peak Base to open $folder"
  }

  "find-vaults" {
    $cfg = Join-Path $env:APPDATA "obsidian\obsidian.json"
    if (-not (Test-Path $cfg)) { "no Obsidian vaults found (no $cfg)"; break }
    $j = Get-Content $cfg -Raw | ConvertFrom-Json
    Out-Json @($j.vaults.PSObject.Properties | ForEach-Object {
      $p = $_.Value.path
      $exists = Test-Path $p
      $files = 0; $mb = 0
      if ($exists) {
        $all = Get-ChildItem $p -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "\\\.(git|obsidian|trash)\\" }
        $files = @($all).Count; $mb = [Math]::Round((($all | Measure-Object Length -Sum).Sum) / 1MB, 1)
      }
      [ordered]@{
        path = $p; exists = $exists; last_open = $(if ($_.Value.open) { $true } else { $false })
        opened = ([DateTimeOffset]::FromUnixTimeMilliseconds([int64] $_.Value.ts)).LocalDateTime.ToString("yyyy-MM-dd")
        in_cloud_storage = ($p -match "OneDrive|iCloud|Dropbox|Google Drive|GoogleDrive|Box")
        files = $files; megabytes = $mb
        has_skills = (Test-Path (Join-Path $p ".claude\skills")) -or (Test-Path (Join-Path $p ".agents\skills"))
      }
    })
  }
  "move-vault" {
    # move-vault <from> [to]: copy out of cloud storage, then compare counts.
    $from = (Resolve-Path (Arg 0 "folder")).Path
    $to = $(if ($Rest.Count -gt 1) { $Rest[1] } else { Join-Path ([Environment]::GetFolderPath("UserProfile")) "Business Brain" })
    if ((Test-Path $to) -and @(Get-ChildItem $to -Force).Count -gt 0) { throw "$to already has files in it; pick another place" }
    # /E all folders, /COPY:DAT data and times, /R:2 /W:2 short retries for
    # files OneDrive is still downloading. Robocopy exit codes below 8 are success.
    robocopy $from $to /E /COPY:DAT /DCOPY:T /R:2 /W:2 /NFL /NDL /NJH /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }
    $a = @(Get-ChildItem $from -Recurse -File -Force -ErrorAction SilentlyContinue).Count
    $b = @(Get-ChildItem $to -Recurse -File -Force -ErrorAction SilentlyContinue).Count
    $offline = @(Get-ChildItem $to -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Attributes -band 0x400000 }).Count
    Out-Json ([ordered]@{ from = $from; to = $to; files_before = $a; files_after = $b; still_online_only = $offline; same = ($a -eq $b -and $offline -eq 0) })
  }

  "reset-password" {
    # reset-password <address> <email>: a private box for the new password, then
    # the server sets it with the recovery key from Credential Manager.
    $address = (Arg 0 "address") -replace "^https?://", "" -replace "/+$", ""
    $base = "https://$address"
    # A local test server (http://localhost:<port>) keeps plain http.
    if ((Arg 0 "address") -match "^http://(localhost|127\.0\.0\.1)(:\d+)?") { $base = $Matches[0] }
    $email = Arg 1 "email"
    $key = Need-Secret "recovery-key"
    $pw = Show-SecretBox "Peak Base: new password" "Pick a new Peak Base password for $email (at least 8 characters). Only you will see it." $true 8
    if (-not $pw) { "cancelled"; break }
    $body = [ordered]@{ email = $email; password = $pw } | ConvertTo-Json -Compress
    try {
      Invoke-WebRequest -Uri "$base/api/peak/recover-password" -Method POST -UseBasicParsing `
        -Headers @{ Authorization = "Bearer $key" } -ContentType "application/json" `
        -Body ([Text.Encoding]::UTF8.GetBytes($body)) | Out-Null
      "ok: the new password is set. Sign in with it in Peak Base."
    } catch {
      $text = $_.Exception.Message
      if ($_.Exception.Response) { try { $text = (New-Object IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {} }
      throw "the server refused: $text"
    }
  }

  "pack-mail-key" {
    # Peak Systems only: pack-mail-key "<from address>". Reads the Resend key
    # saved with ask-secret resend-api-key and writes mail.key beside this script.
    $from = Arg 0 "from address"
    $k = Need-Secret "resend-api-key"
    $json = [ordered]@{ key = $k; from = $from } | ConvertTo-Json -Compress
    Set-Content -Path (Join-Path $Here "mail.key") -Value ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json))) -NoNewline
    "wrote mail.key (keep it out of public downloads)"
  }

  default {
    @"
Peak Base setup helper. Commands:
  ask-secret <name> <title> <message> [minLength] [confirm]   private box, saved in Credential Manager
  has-secret <name> | make-secret <name> [length] | forget-secret <name>
  check-token | servers | options
  setup-server <id> <dataCenterId> [templateId] | set-root-password <id>
  recreate-server <id> erase-everything [templateId] | wait-server <id> [minutes]
  deploy <id> <address> | update-server <id> | projects <id> | containers <id> | logs <id> | firewall <id> | health <address> [minutes]
  install-app | open-connect <address> | open-folder <folder> [skills]
  find-vaults | move-vault <from> [to]
  reset-password <address> <email> | pack-mail-key <from>
"@
  }
}
