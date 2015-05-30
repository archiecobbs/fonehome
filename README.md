**fonehome** allows remote access to machines behind firewalls using SSH port forwarding.

The **fonehome client** is a daemon that runs on remote client machines that are behind some firewall that you either do not control or do not want to reconfigure, but which does allow normal outgoing TCP connections. The clients use SSH to connect to a **fonehome server** to which you have direct access. The SSH connections include reverse-forwarded TCP ports which in turn allow you to connect back to the remote machine.

This setup is useful in situations where you have several machines deployed in the field and want to maintain access to them from a central operations server.

**fonehome** also supports connecting to multiple servers at the same time, each with different forwarded ports, etc.

[Read more about it](Setup).
