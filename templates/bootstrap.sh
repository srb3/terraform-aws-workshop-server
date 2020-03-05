%{ if system_type == "linux" }#!/bin/bash -x %{ endif } %{if system_type == "windows" } <powershell>  %{ endif }
%{ if system_type == "linux" }
exec > /tmp/terraform_bootstrap_script.log 2>&1

function set_tmp_path() {
  if [[ ! -d ${tmp_path} ]]; then
    mkdir -p ${tmp_path}
  fi
}

function install_chef() {
  if ! hash curl; then
    wget -O ${tmp_path}/install.sh ${chef_product_install_url}
  else
    curl -L -o ${tmp_path}/install.sh ${chef_product_install_url}
  fi
  bash ${tmp_path}/install.sh -P $${1} -v $${2}
  case $${1} in
    inspec)
      echo "export PATH=\"$${PATH}:/opt/chef/bin:/opt/chef/embedded/bin\"" >> /root/.bash_profile
      echo "export PATH=\"$${PATH}:/opt/chef/bin:/opt/chef/embedded/bin\"" >> /home/${user_name}/.bash_profile
      ;;
    chef-workstation)
      echo "export PATH=\"$${PATH}:/opt/chef-workstation/bin:/opt/chef-workstation/embedded/bin:/opt/chef-workstation/gitbin/\"" >> /root/.bash_profile
      echo "export PATH=\"$${PATH}:/opt/chef-workstation/bin:/opt/chef-workstation/embedded/bin:/opt/chef-workstation/gitbin/\"" >> /home/${user_name}/.bash_profile
      ;;
    chefdk)
      echo "export PATH=\"$${PATH}:/opt/chefdk/bin:/opt/chefdk/embedded/bin:/opt/chefdk/gitbin/\"" >> /root/.bash_profile
      echo "export PATH=\"$${PATH}:/opt/chefdk/bin:/opt/chefdk/embedded/bin:/opt/chefdk/gitbin/\"" >> /home/${user_name}/.bash_profile
      ;;
    inspec)
      echo "export PATH=\"$${PATH}:/opt/inspec/bin:/opt/inspec/embedded/bin\"" >> /root/.bash_profile
      echo "export PATH=\"$${PATH}:/opt/inspec/bin:/opt/inspec/embedded/bin\"" >> /home/${user_name}/.bash_profile
      ;;

  esac
}

function install_hab() {
  if ! hash curl; then
    wget -O ${tmp_path}/install_hab.sh ${hab_install_url}
  else
    curl -L -o ${tmp_path}/install_hab.sh ${hab_install_url}
  fi
  if [[ "$${1}" == "latest" ]]; then
    bash ${tmp_path}/install_hab.sh
  else
    bash ${tmp_path}/install_hab.sh -v $${1}
  fi
  hab license accept
  su - ${user_name} -c 'hab license accept'
}

%{ if set_hostname }
%{ if ip_hostname }
HNAME=${hostname}-$(hostname -I | sed 's/\./-/g')
%{ else }
HNAME=${hostname}
%{ endif }
if hash hostnamectl &>/dev/null; then
  hostnamectl set-hostname $${HNAME}
fi
%{ endif }

%{ if install_workstation_tools }
  if hash yum &>/dev/null; then
    yum install -y vim git
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y http://ftp.riken.jp/Linux/cern/centos/7/extras/x86_64/Packages/container-selinux-2.107-1.el7_6.noarch.rpm
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl restart docker
  elif hash apt &>/dev/null; then
    apt get install -y vim
  elif hash zypper &>/dev/null; then
    zypper install -y vim
  fi
%{ endif }

%{ if create_user }
if sed 's/"//g' /etc/os-release |grep -e '^NAME=CentOS' -e '^NAME=Fedora' -e '^NAME=Red'; then
  useradd ${user_name}
  usermod -a -G wheel ${user_name}
  %{ if user_pass != "" }
  echo "${user_pass}" | passwd --stdin ${user_name}
  %{ endif }
elif sed 's/"//g' /etc/os-release |grep -e '^NAME=Mint' -e '^NAME=Ubuntu' -e '^NAME=Debian'; then
  apt-get clean
  apt-get update
  useradd ${user_name} -s /bin/bash -m
  usermod -a -G sudo ${user_name}
  %{ if user_pass != "" }
  echo -e "${user_pass}\n${user_pass}" | passwd ${user_name}
  %{ endif }
elif sed 's/"//g' /etc/os-release |grep -e '^NAME=SLES'; then
  if ! grep $(hostname) /etc/hosts; then
    echo "127.0.0.1 $(hostname)" >> /etc/hosts
  fi
  %{ if user_pass != "" }
  pass=$(perl -e 'print crypt($ARGV[0], "password")' ${user_pass})
  useradd -U -m -p $pass ${user_name}
  %{ else }
  useradd -U -m ${user_name}
  %{ endif }
fi

printf >"/etc/sudoers.d/${user_name}" '%s    ALL= NOPASSWD: ALL\n' "${user_name}"

%{ if user_public_key != "" }
mkdir -p /home/${user_name}/.ssh
chmod 700  /home/${user_name}/.ssh
cat << EOF >>/home/${user_name}/.ssh/authorized_keys
${user_public_key}
EOF
chmod 600 /home/${user_name}/.ssh/authorized_keys
chown -R ${user_name}:${user_name} /home/${user_name}/.ssh
%{ else }
sed -i  's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
%{ endif }
%{ endif }

%{ if workstation_chef }
  set_tmp_path
  install_chef ${chef_product_name} ${chef_product_version}
%{ endif }

%{ if workstation_hab }
  set_tmp_path
  install_hab ${hab_version}
%{ endif }

%{ if populate_hosts }
if ! grep "$(hostname -I) $(hostname)" /etc/hosts; then
  echo "$(hostname -I) $(hostname)" >> /etc/hosts
fi
%{ endif }

touch /tmp/bootstrapped.lock

%{ endif }
%{ if system_type == "windows" }
Set-MpPreference -DisableRealtimeMonitoring $true
%{ if create_user }
%{ if user_name == "Administrator" || user_name == "administrator" }
$MySecureString = ConvertTo-SecureString -String "${user_pass}" -AsPlainText -Force
$UserAccount = Get-LocalUser -Name "Administrator"
$UserAccount | Set-LocalUser -Password $MySecureString
%{ endif }

net user ${user_name} '${user_pass}' /add /y
net localgroup administrators ${user_name} /add
%{ endif }

$Logfile = $MyInvocation.MyCommand.Path -replace '\.ps1$', '.log'
Start-Transcript -Path $Logfile

winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'
winrm set winrm/config '@{MaxTimeoutms="1800000"}'

winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow

net stop winrm
sc.exe config winrm start=auto
net start winrm

%{ if user_name != "Administrator" || user_name != "administrator" }

if(!(test-path (Split-Path -Path  'C:\Users\Administrator\Documents\WindowsPowerShell\profile.ps1'))) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Path  'C:\Users\Administrator\Documents\WindowsPowerShell\profile.ps1')
}
%{ endif }

if(!(test-path (Split-Path -Path  'C:\Users\${user_name}\Documents\WindowsPowerShell\profile.ps1'))) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Path  'C:\Users\${user_name}\Documents\WindowsPowerShell\profile.ps1')
}

function install_choco {
  if( -Not (Test-Path -Path "$env:ProgramData\Chocolatey")) {
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('${choco_install_url}'))
  }
}

function update_path {
  Param
  (
    [Parameter(Mandatory=$true, Position=0)]
    [string] $path_entry
  )
  $newpath = "$env:Path;$path_entry"
  [System.Environment]::SetEnvironmentVariable('Path',$newpath,[System.EnvironmentVariableTarget]::User)
}

%{ if install_workstation_tools }
install_choco
choco install git -y
choco install googlechrome -y
update_path '$${env:ProgramFiles(x86)}\Google\Chrome\Application'
choco install vscode -y
update_path '$${env:ProgramFiles}\Microsoft VS Code'
%{ endif }

%{ if workstation_hab }
install_choco
  %{ if hab_version == "latest" }
choco install habitat -y
  %{ else }
choco install habitat --version ${hab_version} -y
  %{ endif }
hab license accept
%{ endif }

%{ if workstation_chef }
install_choco

%{ if chef_product_version == "latest" }
choco install ${chef_product_name} -y
%{ else }
choco install ${chef_product_name} --version ${chef_product_version} -y
%{ endif }

%{ if chef_product_name == "chef-workstation" }
update_path 'C:\opscode\chef-workstation\bin;C:\opscode\chef-workstation\embedded\bin\'
%{ endif }

%{ if chef_product_name == "chef" }
update_path 'C:\opscode\chef\bin;C:\opscode\chef\embedded\bin\'
%{ endif }

%{ if chef_product_name == "chefdk" }
update_path 'C:\opscode\chefdk\bin\;C:\opscode\chefdk\embedded\bin\'
%{ endif }

%{ if chef_product_name == "inspec" }
update_path 'C:\opscode\inspec\bin;C:\opscode\inspec\embedded\bin\'
%{ endif }
%{ endif }
%{ for k in jsondecode(helper_files) }
$helper_file = @"
${join("\n", k.script)}
"@
$dtp = [Environment]::GetFolderPath("CommonDesktopDirectory")
Set-Content -Path $dtp\\${k.name} -Value $helper_file
%{ endfor}

%{ if kb_uk }
Set-WinUserLanguageList -LanguageList en-GB -Force
%{ endif }

%{ if wsl }
if ((Get-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux').State -ne 'Enabled') {
  $ProgressPreference = 'SilentlyContinue'
  cd C:\
  Push-Location $(Get-Location)
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
  Invoke-WebRequest -Uri  https://aka.ms/wsl-ubuntu-1804 -OutFile Ubuntu.appx -UseBasicParsing
  Rename-Item ./Ubuntu.appx ./Ubuntu.zip
  Expand-Archive ./Ubuntu.zip ./Ubuntu
  Remove-Item ./Ubuntu.zip
  Push-Location .\Ubuntu\
  $file_exe=$(Get-ChildItem .\ubuntu1804.exe -Recurse | % { $_.FullName })
  $wsl = @"
$file_exe install --root
Unregister-ScheduledJob WSLsetup
Remove-Item C:\wsl_setup.ps1
"@
  Set-Content -Path C:\wsl_setup.ps1 -Value $wsl
  Register-ScheduledJob –Name WSLsetup –FilePath C:\wsl_setup.ps1 -ScheduledJobOption (New-ScheduledJobOption –DoNotAllowDemandStart)  -Trigger (New-JobTrigger –AtStartup)
  Pop-Location
}

%{ endif }

Set-MpPreference -DisableRealtimeMonitoring $false
# writing lock file
echo $null >> "C:\\TEMP\\bootstrapped.lock"
Stop-Transcript
</powershell>
%{ endif }
