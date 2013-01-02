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
Version:        %{fonehome_version}
Release:        1
Summary:        Remote access to machines behind firewalls
Group:          System/Daemons
License:        Apache
BuildRoot:      %{_tmppath}/%{name}-root
Buildarch:      noarch
Source:         %{name}-%{version}.tar.gz
URL:            http://code.google.com/p/%{name}/
Requires:       openssh

%description
%{summary}.

%clean
rm -rf %{buildroot}

%prep
%setup

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
subst < src/conf/fonehome.conf.sample > fonehome.conf.sample
subst < src/conf/fonehome-ports.conf.sample > fonehome-ports.conf.sample
subst < src/scripts/fonehome-init.sh > fonehome-init
subst < src/scripts/fonehome.sh > fonehome
subst < src/scripts/fhshow.sh > fhshow
subst < src/scripts/fhssh.sh > fhssh
subst < src/man/fhssh.1 > fhssh.1
subst < src/man/fhscp.1 > fhscp.1
subst < src/man/fhshow.1 > fhshow.1

%install

# init script
install -d %{buildroot}%{_sysconfdir}/init.d
install fonehome-init %{buildroot}%{initfile}

# init man pages
install -d %{buildroot}%{_mandir}/man1
install fhs{sh,cp,how}.1 %{buildroot}%{_mandir}/man1/

# script files
install -d %{buildroot}%{_bindir}
install fonehome fhs{sh,how} %{buildroot}/%{_bindir}/
ln %{buildroot}/%{_bindir}/fhs{sh,cp}

# config files
install -d %{buildroot}%{confdir}
install -d %{buildroot}%{pkgdir}
install fonehome.conf.sample %{buildroot}%{pkgdir}/
install -d %{buildroot}%{pkgdir2}
install fonehome-ports.conf.sample %{buildroot}%{pkgdir2}/

# fonehome user
install -d %{buildroot}%{homedir}/.ssh

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
Group:          System/Daemons
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
%{_mandir}/man1/*
%attr(755,root,root) %{_bindir}/fhshow
%attr(755,root,root) %{_bindir}/fhssh
%attr(755,root,root) %{_bindir}/fhscp
%attr(755,%{username},%{usergroup}) %{homedir}
%attr(700,%{username},%{usergroup}) %{homedir}/.ssh

