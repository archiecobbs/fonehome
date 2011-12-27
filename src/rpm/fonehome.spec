# $Id$

%define name        fonehome
%define username    %{name}
%define usergroup   users
%define pkgdir      %{_datadir}/%{name}
%define pkgdir2     %{_datadir}/%{name}-server
%define homedir     /home/%{username}
%define sshd_config %{_sysconfdir}/ssh/sshd_config
%define scriptfile  %{_bindir}/%{name}
%define initfile    %{_sysconfdir}/init.d/%{name}
%define confdir     %{_sysconfdir}/%{name}
%define conffile    %{confdir}/%{name}.conf
%define keyfile     %{confdir}/%{name}.key
%define hostsfile   %{confdir}/%{name}.hosts
%define portsfile   %{_sysconfdir}/%{name}-ports.conf
%define retrydelay  30

Name:           %{name}
Version:        1.0.%{svn_revision}
Release:        1
Summary:        Remote access to machines behind firewalls
Group:          Utilities
License:        Apache
BuildRoot:      %{_tmppath}/%{name}-root
Buildarch:      noarch
Source:         %{name}.zip
URL:            http://code.google.com/p/%{name}/
Requires:       openssh

%description
%{summary}.

%clean
rm -rf ${RPM_BUILD_ROOT}

%prep
rm -rf ${RPM_BUILD_ROOT}
%setup -c

%build
subst()
{
    sed -r \
      -e 's|@fonehomename@|%{name}|g' \
      -e 's|@fonehomeuser@|%{username}|g' \
      -e 's|@fonehomeconf@|%{conffile}|g' \
      -e 's|@fonehomeports@|%{portsfile}|g' \
      -e 's|@fonehomekey@|%{keyfile}|g' \
      -e 's|@fonehomehosts@|%{hostsfile}|g' \
      -e 's|@fonehomeretry@|%{retrydelay}|g' \
      -e 's|@fonehomescript@|%{scriptfile}|g'
}
subst < conf/fonehome.conf.sample > fonehome.conf.sample
subst < conf/fonehome-ports.conf.sample > fonehome-ports.conf.sample
subst < scripts/fonehome-init.sh > fonehome-init
subst < scripts/fonehome.sh > fonehome
subst < scripts/fhshow.sh > fhshow
subst < scripts/fhssh.sh > fhssh

%install

# init script
install -d ${RPM_BUILD_ROOT}%{_sysconfdir}/init.d
install fonehome-init ${RPM_BUILD_ROOT}%{initfile}

# script files
install -d ${RPM_BUILD_ROOT}%{_bindir}
install fonehome fhshow fhssh ${RPM_BUILD_ROOT}/%{_bindir}/
ln ${RPM_BUILD_ROOT}/%{_bindir}/fh{ssh,scp}

# config files
install -d ${RPM_BUILD_ROOT}%{confdir}
install -d ${RPM_BUILD_ROOT}%{pkgdir}
install fonehome.conf.sample ${RPM_BUILD_ROOT}%{pkgdir}/
install -d ${RPM_BUILD_ROOT}%{pkgdir2}
install fonehome-ports.conf.sample ${RPM_BUILD_ROOT}%{pkgdir2}/

# fonehome user
install -d ${RPM_BUILD_ROOT}%{homedir}/.ssh

%preun
if [ "$1" -eq 0 ]; then
    chkconfig --del %{name} >/dev/null
fi

%post

# Install sample config file
if ! [ -e %{conffile} ]; then
    cp -a %{pkgdir}/fonehome.conf.sample %{conffile}
fi

%files
%attr(700,root,root) %dir %{confdir}
%attr(755,root,root) %{initfile}
%attr(755,root,root) %{scriptfile}
%defattr(644,root,root,755)
%{pkgdir}

%package server
Summary:        Server for %{name} SSH connections
Group:          Utilities
Requires(pre):  pwdutils
Requires(pre):  openssh

%description server
%{summary}.

%pre server

# Create user
if ! grep -q '^%{username}:' /etc/passwd; then
    useradd -p '*' -M -d '%{homedir}' -g '%{usergroup}' -c 'Fonehome User' -s /bin/true '%{username}'
fi

%preun server
if [ "$1" -eq 0 ]; then
    userdel '%{username}'
fi

%post server

# Handy function
sed_patch_file()
{
    FILE="${1}"
    shift
    sed ${1+"$@"} < "${FILE}" > "${FILE}".new
    if ! diff -q "${FILE}" "${FILE}".new >/dev/null; then
        [ -e "${FILE}".old ] || cp -a "${FILE}"{,.old}
        cat "${FILE}".new > "${FILE}"
    fi
    rm -f "${FILE}".new
}

# Tweak SSHD config so it quickly detects a disconnected client (hopefully before the client does)
sed_patch_file %{sshd_config} -r \
  -e 's/^([[:space:]]*#)?([[:space:]]*TCPKeepAlive[[:space:]]).*$/\2yes/g' \
  -e 's/^([[:space:]]*#)?([[:space:]]*ClientAliveInterval[[:space:]]).*$/\220/g' \
  -e 's/^([[:space:]]*#)?([[:space:]]*ClientAliveCountMax[[:space:]]).*$/\23/g'

# Generate ssh key pair for user fonehome
if ! [ -e %{homedir}/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N '' -f %{homedir}/.ssh/id_rsa
    chmod 600 %{homedir}/.ssh/id_rsa
    chown root:root %{homedir}/.ssh/id_rsa
fi

# Allow incoming ssh connections, with restrictions
sed -r 's/^.*(ssh-rsa[[:space:]].*)$/no-X11-forwarding,no-agent-forwarding,command="sleep 365d" \1/g' \
 < %{homedir}/.ssh/id_rsa.pub > %{homedir}/.ssh/authorized_keys

# Set ownership and permissions
chown %{username}:%{usergroup} %{homedir}/.ssh/{id_rsa.pub,authorized_keys}

# Install sample ports file
if ! [ -e %{portsfile} ]; then
    cp -a %{pkgdir2}/fonehome-ports.conf.sample %{portsfile}
fi

%files server
%defattr(644,root,root,755)
%{pkgdir2}
%attr(755,root,root) %{_bindir}/fhshow
%attr(755,root,root) %{_bindir}/fhssh
%attr(755,root,root) %{_bindir}/fhscp
%attr(755,%{username},%{usergroup}) %{homedir}
%attr(700,%{username},%{usergroup}) %{homedir}/.ssh

