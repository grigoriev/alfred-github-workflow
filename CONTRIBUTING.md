# Contributing

Thanks for your interest in improving this project.

## Development

See the [README](README.md) for build and test steps. In short:

```sh
make lint     # ShellCheck the action scripts
make test     # run the bats tests
make build    # build the workflow bundle
```

## Commit messages

This project follows [Conventional Commits](https://www.conventionalcommits.org/):
`type: subject`, imperative mood, lowercase first letter, no trailing period,
subject under 50 characters. Types: `feat`, `fix`, `docs`, `style`, `refactor`,
`perf`, `test`, `build`, `ci`, `chore`.

## Style

- American spelling.
- One idea per sentence, active voice.
- Keep changes minimal and focused on the task.
- Do not use em dashes.

## Before opening a pull request

- Run the linter and tests.
- Make sure CI is green.
