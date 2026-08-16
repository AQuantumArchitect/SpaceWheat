# Security Policy

SpaceWheat is a single-player offline game — there's no server, no account
system, and no network service to compromise. The realistic security surface
is narrow: the native C++ GDExtension (`native/`), save-file parsing
(`Core/GameState/`), and the web export's sandboxing.

## Supported versions

Only the latest `main` (and the most recent published release) receives
security fixes. This project is pre-1.0 and versions aren't maintained in
parallel.

## Reporting a vulnerability

If you find a security issue — a crash triggerable by a malicious save file,
a memory-safety bug in the native extension, or anything in the web export
that could escape the browser sandbox — please report it privately rather
than opening a public issue:

- Use GitHub's [private vulnerability reporting](../../security/advisories/new)
  for this repository, or
- Contact the maintainer directly through their GitHub profile.

Please include repro steps and, if possible, the smallest input that
triggers it (a save file, a specific action sequence). We'll acknowledge
reports as soon as practical and credit reporters in the fix unless you'd
prefer otherwise.

Please don't open a public issue for anything you believe is a genuine
security vulnerability until a fix has shipped.
