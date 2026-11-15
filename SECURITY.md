# Security Policy

## Reporting a vulnerability

Please report security vulnerabilities privately through GitHub Security
Advisories:

https://github.com/nekonaru/sphinx/security/advisories/new

Do not open a public issue for security reports. You should get a
first response within 7 days. Please include the affected version, a
short reproduction, and the impact you have in mind.

## Scope

Sphinx is a local, offline puzzle solver. It reads text files you
point it at and prints results. It does not use the network, does not
run subprocesses, and does not store credentials. The main risks are
malicious or oversized puzzle files, so the CLI rejects files larger
than 1 MiB and the parsers reject malformed input.

## Supported versions

Only the latest release receives security fixes.
