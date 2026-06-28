#!/bin/bash
# Script to detect languages and contexts in a repository
# Outputs JSON that can be used to filter bindings

set -e

# Default to unknown
echo "Detecting languages and contexts in repository..."

# Create output object
cat > /tmp/repo-context.json << EOF
{
  "languages": [],
  "contexts": []
}
EOF

# Check for TypeScript
if find . -type f \( -name "*.ts" -o -name "*.tsx" -o -name "tsconfig.json" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: TypeScript"
  jq '.languages += ["typescript"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for JavaScript
if find . -type f \( -name "*.js" -o -name "*.jsx" -o -name "package.json" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: JavaScript"
  jq '.languages += ["javascript"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for Go
if find . -type f \( -name "*.go" -o -name "go.mod" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: Go"
  jq '.languages += ["go"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for Rust
if find . -type f \( -name "*.rs" -o -name "Cargo.toml" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: Rust"
  jq '.languages += ["rust"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for Python
if find . -type f \( -name "*.py" -o -name "requirements.txt" -o -name "setup.py" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: Python"
  jq '.languages += ["python"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for Java
if find . -type f \( -name "*.java" -o -name "pom.xml" -o -name "build.gradle" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: Java"
  jq '.languages += ["java"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for C#
if find . -type f \( -name "*.cs" -o -name "*.csproj" -o -name "*.sln" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: C#"
  jq '.languages += ["csharp"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for Ruby
if find . -type f \( -name "*.rb" -o -name "Gemfile" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected: Ruby"
  jq '.languages += ["ruby"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for frontend context
if find . -type f \( -name "*.html" -o -name "*.css" -o -name "*.jsx" -o -name "*.tsx" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected context: Frontend"
  jq '.contexts += ["frontend"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for backend context
if find . -type f \( -name "*server.js" -o -name "*api.js" -o -name "*controller.go" -o -name "*repository.java" \) | grep -v "_leyline/" | grep -q .; then
  echo "Detected context: Backend"
  jq '.contexts += ["backend"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
elif [[ -d "server" || -d "api" || -d "backend" ]] && [[ ! "$PWD" =~ "_leyline" ]]; then
  echo "Detected context: Backend (via directory structure)"
  jq '.contexts += ["backend"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Check for CLI context
if grep -q "#!/usr/bin/env" . -r --include="*.sh" --include="*.py" --include="*.rb" | grep -v "_leyline/" | grep -q .; then
  echo "Detected context: CLI"
  jq '.contexts += ["cli"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# If we didn't detect any languages, add "all"
if [ "$(jq '.languages | length' /tmp/repo-context.json)" -eq "0" ]; then
  echo "No specific languages detected, defaulting to 'all'"
  jq '.languages += ["all"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# If we didn't detect any contexts, add "all"
if [ "$(jq '.contexts | length' /tmp/repo-context.json)" -eq "0" ]; then
  echo "No specific contexts detected, defaulting to 'all'"
  jq '.contexts += ["all"]' /tmp/repo-context.json > /tmp/repo-context.json.tmp
  mv /tmp/repo-context.json.tmp /tmp/repo-context.json
fi

# Print final detection result
echo "Detection complete:"
cat /tmp/repo-context.json

# Keep the file for later use
cp /tmp/repo-context.json repo-context.json
