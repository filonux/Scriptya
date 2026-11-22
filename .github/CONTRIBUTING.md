# Contributing

Thanks for your interest. Here's the basics:

## Report a bug or propose an improvement

Open an issue — there's a template for each case.

## Submit a change

1. Fork the repo and create a branch from the latest version.
2. Test the change with what the CI (`.github/workflows/quality.yml`) runs, so it passes there too:
   - `bash -n` on every `.sh` file you touched, and `shellcheck script/scriptya.sh` (the CI pins ShellCheck 0.11.0);
   - `python3 tests/lint_globals.py script/scriptya.sh` and `python3 tests/lint_locals.py script/scriptya.sh` (no output means clean);
   - the test suite, `bash tests/test_scriptya.sh`: about 8 minutes, run as a regular user (not root) with `script/scriptya.sh` and `tests/test_scriptya.sh` executable (`chmod +x` them if a download lost the bit). It prints `PASS` or `FAIL` for each check, ends with `Total: N passed, M failed` and must leave the working tree untouched (block 14.3 checks it). The header of `tests/test_scriptya.sh` lists the tools it needs and explains how to run a single block and how to write a test.

   If you can also test it on Linux Mint/Cinnamon (the environment it's developed on), even better.
3. Open the pull request — the template will guide you on what to include.

## Code style

- Bash with `set -uo pipefail`, double quotes on expansions, `--` before paths that might start with `-`.
- Comments only where they clarify a non-obvious "why", not to repeat what the code already says. The one exception is the summary line above every function of `script/scriptya.sh`, `# name <args> -> what it returns or does` (the suite checks it, block 14.4). The header of that file has a map of its sections and the conventions to follow.
- If the change touches icons, `.desktop` files, or desktop paths: it's tested primarily on Cinnamon, so note in the PR if it might affect other environments.
