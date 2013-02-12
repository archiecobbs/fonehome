#
# spec file for package fonehome
#
# Copyright (c) 2012 Archie L. Cobbs <archie@dellroad.org>
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.
#
# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

%define username    %{name}
%define usergroup   %{name}
%define clientdir   %{_datadir}/%{name}
%define serverdir   %{_datadir}/%{name}-server
%define sshd_config %{_sysconfdir}/ssh/sshd_config
%define scriptfile  %{_bindir}/%{name}
%define initfile    %{_sysconfdir}/init.d/%{name}
%define confdir     %{_sysconfdir}/%{name}
%define conffile    %{confdir}/%{name}.conf
%define keyfile     %{confdir}/%{name}.key
%define hostsfile   %{confdir}/%{name}.hosts
%define portsfile   %{_sysconfdir}/%{name}-ports.conf
%define retrydelay  30

Name:           fonehome
Version:        %{fonehome_version}
Release:        1
Summary:        Remote access to machines behind firewalls
Group:          System/Daemons
License:        Apache-2.0
BuildRoot:      %{_tmppath}/%{name}-root
Buildarch:      noarch
Source:         %{name}-%{version}.tar.gz
URL:            http://code.google.com/p/%{name}/
Requires:       openssh

%description
fonehome allows remote access to machines behind firewalls using SSH
port forwarding.

The fonehome client is a daemon that runs on remote client machines that
are behind some firewall that you either do not control or do not want
to reconfigure, but which does allow normal outgoing TCP connections. The
clients use SSH to connect to a fonehome server to which you have direct
access. The SSH connections include reverse-forwarded TCP ports which
in turn allow you to connect back to the remote machine.

This setup is useful in situations where you have several machines
deployed in the field and want to maintain access to them from a central
operations server.

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
      -e 's|@fonehomeinit@|%{initfile}|g' \
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
subst < src/man/fonehome.1 > fonehome.1

%install

# init script
install -d %{buildroot}%{_sysconfdir}/init.d
install fonehome-init %{buildroot}%{initfile}
install -d %{buildroot}%{_sbindir}
ln -s %{initfile} %{buildroot}%{_sbindir}/rcfonehome

# man pages
install -d %{buildroot}%{_mandir}/man1
install *.1 %{buildroot}%{_mandir}/man1/

# docs
install -d %{buildroot}%{_datadir}/doc/packages/%{name}
install -d %{buildroot}%{_datadir}/doc/packages/%{name}-server
install CHANGES README COPYING %{buildroot}%{_datadir}/doc/packages/%{name}/
install CHANGES README COPYING %{buildroot}%{_datadir}/doc/packages/%{name}-server/

# script files
install -d %{buildroot}%{_bindir}
install fonehome fhs{sh,how} %{buildroot}/%{_bindir}/
ln %{buildroot}/%{_bindir}/fhs{sh,cp}

# config files
install -d %{buildroot}%{confdir}
install -d %{buildroot}%{clientdir}
install fonehome.conf.sample %{buildroot}%{clientdir}/
install fonehome.conf.sample %{buildroot}%{conffile}
install fonehome-ports.conf.sample %{buildroot}%{portsfile}

# fonehome user
install -d %{buildroot}%{serverdir}/.ssh

# Create ghost files
install /dev/null %{buildroot}%{hostsfile}
install /dev/null %{buildroot}%{keyfile}
install /dev/null %{buildroot}%{serverdir}/.ssh/id_rsa
install /dev/null %{buildroot}%{serverdir}/.ssh/id_rsa.pub
install /dev/null %{buildroot}%{serverdir}/.ssh/authorized_keys

%preun
%{stop_on_removal %{name}}

%postun
# No restart_on_update - don't kill the connection we are using to update this RPM with!
%{insserv_cleanup}

%files
%defattr(644,root,root,755)
%dir %attr(700,root,root) %{confdir}
%config(noreplace) %{conffile}
%ghost %attr(644,root,root) %{hostsfile}
%ghost %attr(600,root,root) %{keyfile}
%attr(755,root,root) %{initfile}
%attr(755,root,root) %{scriptfile}
%attr(755,root,root) %{_sbindir}/rcfonehome
%doc %{_datadir}/doc/packages/%{name}
%{_mandir}/man1/fonehome.1*
%{clientdir}

%package server
Summary:        Server for %{name} SSH connections
Group:          System/Daemons
Requires(pre):  pwdutils
Requires(post): openssh

%description server
fonehome allows remote access to machines behind firewalls using SSH
port forwarding. This package is installed on the machine that you
want to be the fonehome server.

%pre server

# Create user and group
if ! getent group '%{usergroup}' >/dev/null 2>&1; then
    groupadd -r '%{usergroup}'
fi
if ! id '%{username}' >/dev/null 2>&1; then
    useradd -r -p '*' -d '%{serverdir}' -g '%{usergroup}' -c 'Fonehome User' -s /bin/false '%{username}'
fi

%post server

# Function that patches a file using sed(1).
# First argument is filename, subsequent arguments are passed to sed(1).
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
if ! [ -e %{serverdir}/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N '' -C '%{username}' -f %{serverdir}/.ssh/id_rsa
    chmod 600 %{serverdir}/.ssh/id_rsa
    chown root:root %{serverdir}/.ssh/id_rsa
fi

# Allow incoming ssh connections, with restrictions
sed -r 's/^.*(ssh-rsa[[:space:]].*)$/no-X11-forwarding,no-agent-forwarding,command="sleep 365d" \1/g' \
 < %{serverdir}/.ssh/id_rsa.pub > %{serverdir}/.ssh/authorized_keys

# Set ownership and permissions
chmod 644 %{serverdir}/.ssh/{id_rsa.pub,authorized_keys}
chown %{username}:%{usergroup} %{serverdir}/.ssh/{id_rsa.pub,authorized_keys}

%files server
%defattr(644,root,root,755)
%{_mandir}/man1/fhssh.1*
%{_mandir}/man1/fhscp.1*
%{_mandir}/man1/fhshow.1*
%doc %{_datadir}/doc/packages/%{name}-server
%attr(755,root,root) %{_bindir}/fhshow
%attr(755,root,root) %{_bindir}/fhssh
%attr(755,root,root) %{_bindir}/fhscp
%config(noreplace missingok) %{portsfile}
%dir %attr(755,%{username},%{usergroup}) %{serverdir}
%dir %attr(700,%{username},%{usergroup}) %{serverdir}/.ssh
%ghost %verify(not size md5 mtime) %attr(600,root,root) %{serverdir}/.ssh/id_rsa
%ghost %verify(not size md5 mtime) %attr(644,%{username},%{usergroup}) %{serverdir}/.ssh/id_rsa.pub
%ghost %verify(not size md5 mtime) %attr(644,%{username},%{usergroup}) %{serverdir}/.ssh/authorized_keys

