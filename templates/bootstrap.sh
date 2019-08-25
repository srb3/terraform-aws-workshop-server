%{ if system_type == "linux" }#!/bin/bash -x %{ else } <powershell>  %{ endif }
%{ if system_type == "linux" }
exec > /tmp/terraform_bootstrap_script.log 2>&1

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
  echo "${user_pass}" | passwd --stdin ${user_name}
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
%{ else }
%{ if create_user }
%{ if user_name == "Administrator" || user_name == "administrator" }
$MySecureString = ConvertTo-SecureString -String "${user_pass}" -AsPlainText -Force
$UserAccount = Get-LocalUser -Name "Administrator"
$UserAccount | Set-LocalUser -Password $MySecureString
%{ endif }

net user ${user_name} '${user_pass}' /add /y
net localgroup administrators ${user_name} /add
%{ endif }

winrm quickconfig -q
winrm set winrm/config/winrs '@{MaxMemoryPerShellMB=”300″}'
winrm set winrm/config '@{MaxTimeoutms=”1800000″}'

winrm set winrm/config/client/auth '@{Basic="true"}'
winrm set winrm/config/service/auth '@{Basic="true"}'
winrm set winrm/config/service '@{AllowUnencrypted="true"}'

netsh advfirewall firewall add rule name="WinRM 5985" protocol=TCP dir=in localport=5985 action=allow
netsh advfirewall firewall add rule name="WinRM 5986" protocol=TCP dir=in localport=5986 action=allow

net stop winrm
sc.exe config winrm start=auto
net start winrm
</powershell>
%{ endif }
