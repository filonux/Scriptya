# Contributing

Thanks for your interest. Here's the basics:

## Report a bug or propose an improvement

Open an issue — there's a template for each case.

## Submit a change

1. Fork the repo and create a branch from the latest version.
2. Test the change: at minimum, `bash -n script/scriptya.sh` with no errors; if you have `shellcheck` installed, run that too. If you can test it on Linux Mint/Cinnamon (the environment it's developed on), even better.
3. Open the pull request — the template will guide you on what to include.

## Code style

- Bash with `set -uo pipefail`, double quotes on expansions, `--` before paths that might start with `-`.
- Comments only where they clarify a non-obvious "why", not to repeat what the code already says.
- If the change touches icons, `.desktop` files, or desktop paths: it's tested primarily on Cinnamon, so note in the PR if it might affect other environments.
