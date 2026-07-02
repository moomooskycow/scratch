# CLAUDE.md - Coding Assistant Guidelines

## Build & Run Commands
- Install: `go install`
- Run app: `scratch`
- Format code: `go fmt ./...`
- Run tests: `go test ./...`
- Run specific test: `go test -run TestName`
- Lint: `golangci-lint run`

## Code Style Guidelines
- **Imports**: Standard library first, third-party separated with comment
- **Error handling**: Check errors immediately after function calls with `if err != nil`
- **Naming**: camelCase for variables/functions; descriptive names
- **Functions**: Small, single-purpose functions with descriptive comments
- **Formatting**: Standard Go formatting with proper indentation
- **Color logging**: Use `info`, `warn`, `fatal` color helpers for console output
- **Resource cleanup**: Use `defer` for file handles and similar resources
- **Docs**: Each function should have a comment describing purpose
- **Dependencies**: Only use necessary external packages