# Contributing to auth0_flutter_auth

We welcome contributions from the community. Before submitting a pull request, please read through this guide.

## Getting Started

1. Fork and clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter test` to verify the test suite passes

## Development

### Project Structure

```
lib/
  src/
    api/           # AuthApi — pure Dart HTTP calls to Auth0 endpoints
    credentials/   # CredentialStore — secure storage with auto-refresh
    web_auth/      # WebAuth — browser-based PKCE login/logout
    dpop/          # DPoP — hardware-backed proof-of-possession
    passkeys/      # Passkeys — WebAuthn registration and authentication
    jwt/           # JWT decoding and validation
    models/        # Data models (Credentials, UserProfile, etc.)
    exceptions/    # Typed exception hierarchy
test/              # Unit tests (mocked, no device required)
integration_test/  # E2E tests (require device + Auth0 tenant)
example/           # Example Flutter app
```

### Running Tests

**Unit tests** (no device needed):

```bash
flutter test
```

**Integration tests** (require a device and Auth0 tenant):

```bash
# Copy the env template and fill in your Auth0 credentials
cp .env.test.example .env.test

# Run on a connected device
cd example
flutter test integration_test/ -d <device-id> --dart-define-from-file=../.env.test
```

See `.env.test.example` for Auth0 tenant setup instructions.

### Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Run `flutter analyze` before submitting — it should report 0 issues
- Keep dependencies minimal; avoid adding packages unless necessary

### Writing Tests

- **Unit tests**: Use hand-written mocks (see `test/dpop_mock_test.dart` or `test/passkeys_class_test.dart` for examples). This avoids code generation overhead.
- **Integration tests**: Run against a real Auth0 tenant. Use `diagnoseApiError()` from `test_helpers.dart` to surface helpful messages when Auth0 config issues cause failures.
- New features should include both unit tests and integration tests where applicable.

## Pull Requests

1. Create a feature branch from `development`
2. Write tests for your changes
3. Run `flutter analyze` and `flutter test` to verify
4. Open a PR against `development` with a clear description of the change
5. Keep PRs focused — one feature or fix per PR

## Reporting Issues

Open an issue on [GitHub](https://github.com/Mmckelve45/auth0_flutter_auth/issues) with:
- A clear description of the problem
- Steps to reproduce
- Expected vs. actual behavior
- Flutter version (`flutter --version`)
- Platform (iOS, Android, macOS, Web)
