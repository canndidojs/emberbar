#!/bin/bash
# Fails if the repository contains something that looks like personal data or a credential.
set -u
cd "$(git rev-parse --show-toplevel)"
fail=0

# 1) Files that must never be tracked.
bad=$(git ls-files | grep -Ei '(^|/)(auth\.dat|\.env(\..*)?|history\.json|settings\.json|\.credentials\.json)$|\.(p12|pem|pfx|mobileprovision|key)$' || true)
if [ -n "$bad" ]; then echo "Forbidden files tracked:"; echo "$bad"; fail=1; fi

# 2) Credential-looking strings and personal paths/emails in tracked text files.
pattern='gh[pousr]_[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9_-]{10,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.|"(access|refresh)_token"[[:space:]]*:[[:space:]]*"[A-Za-z0-9._-]{20,}|[A-Za-z0-9._%+-]+@(gmail|hotmail|outlook|yahoo|icloud|live)\.[a-z.]+|[A-Za-z]:\Users\[A-Za-z0-9._ -]+|/Users/[a-z0-9._-]+/'
hits=$(git grep -nIE "$pattern" -- . ':!.github/scripts/privacy-guard.sh' ':!*.png' ':!*.ico' || true)
if [ -n "$hits" ]; then echo "Possible secret or personal data:"; echo "$hits"; fail=1; fi

# 3) Commit authors must use the GitHub noreply address, not a real mailbox.
emails=$(git log --format='%ae%n%ce' | sort -u | grep -v '@users.noreply.github.com' || true)
if [ -n "$emails" ]; then echo "Commit e-mail is not a noreply address:"; echo "$emails"; fail=1; fi

[ $fail -eq 0 ] && echo "privacy guard: clean"
exit $fail
