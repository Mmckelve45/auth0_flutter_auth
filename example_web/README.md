# Auth0 Flutter Auth - Web Example App

This is an example of how to integrate Auth0 authentication into a Flutter web application using the `auth0_flutter_auth` package.

## Features

- OAuth 2.0 + PKCE authentication flow
- Redirect-based flow (no popup windows)
- Automatic callback handling
- Secure token storage
- User profile display
- Logout functionality

## Prerequisites

- Flutter SDK (latest stable version with web support enabled)
- Auth0 account and application
- Modern web browser (Chrome, Firefox, Safari, Edge)

## Setup Instructions

### 1. Configure Auth0 Application

1. Go to [Auth0 Dashboard](https://manage.auth0.com)
2. Create or select your application and set the type to **Single Page Application**
3. In **Settings**, configure the following URLs:

   **Allowed Callback URLs:**
   ```
   http://localhost:PORT/callback
   https://YOUR_DOMAIN.com/callback
   ```

   **Allowed Logout URLs:**
   ```
   http://localhost:PORT
   https://YOUR_DOMAIN.com
   ```

   **Allowed Web Origins:**
   ```
   http://localhost:PORT
   https://YOUR_DOMAIN.com
   ```

   (Replace `PORT` with your local development port, typically `5173` or `8080`, and `YOUR_DOMAIN.com` with your production domain)

### 2. Configure Local Environment

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your Auth0 credentials:
   ```
   AUTH0_DOMAIN=YOUR_DOMAIN.auth0.com
   AUTH0_CLIENT_ID=YOUR_CLIENT_ID
   ```

### 3. Install Dependencies

```bash
flutter pub get
```

## Running the App

```bash
flutter run -d chrome
```

The app will typically run on `http://localhost:5173` (check console output for the actual port).

## App Structure

### Pages

- **Home Page**: Initial login page with Auth0 login button
- **Callback Page**: Handles OAuth redirect and token exchange
- **Profile Page**: Displays user information and logout button

### Key Files

- `lib/main.dart`: Application entry point
- `lib/pages/home_page.dart`: Login UI
- `lib/pages/callback_page.dart`: Callback handler
- `lib/pages/profile_page.dart`: User profile display
- `web/index.html`: Web entry point
- `.env`: Environment variables (create from `.env.example`)

## Authentication Flow

### Login Flow

1. User clicks "Login with Auth0" on Home Page
2. App builds authorization URL with PKCE parameters
3. Browser redirects to Auth0 login page via `window.location.href`
4. User authenticates and consents
5. Auth0 redirects back to callback URL with auth code
6. Callback handler exchanges code for tokens
7. Tokens stored securely (localStorage or sessionStorage)
8. User navigated to Profile Page

### Logout Flow

1. User clicks "Logout" on Profile Page
2. Tokens cleared from storage
3. Browser redirected to Auth0 logout endpoint
4. User returned to Home Page

## Configuration Details

### PKCE Implementation

The example uses PKCE (Proof Key for Code Exchange) for enhanced security:
- Code challenge generated from random code verifier
- Code verifier stored temporarily during callback handling
- Auth code exchanged for tokens using code verifier

### Token Management

- **Access Token**: Used for API requests (if needed)
- **ID Token**: Contains user profile information (JWT format)
- **Stored Securely**: Tokens stored in browser storage with appropriate security measures

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AUTH0_DOMAIN` | Your Auth0 domain | `example.auth0.com` |
| `AUTH0_CLIENT_ID` | Your application's client ID | `abcd1234...` |

## Troubleshooting

### Callback not working
- Verify callback URL in Auth0 Dashboard matches your local URL exactly (including port)
- Check browser console for errors
- Ensure cookies are enabled

### CORS errors
- Add your URL to "Allowed Web Origins" in Auth0 Dashboard
- Verify the application type is set to "Single Page Application"

### Token storage issues
- Check browser DevTools → Application tab for localStorage/sessionStorage
- Verify browser allows storage for your domain
- Clear browser cache and try again

### Build issues
- Run `flutter clean` and `flutter pub get`
- Delete `.dart_tool` directory and rebuild
- Ensure web platform is enabled: `flutter config --enable-web`

## Local Development with HTTPS

For testing with HTTPS locally:

```bash
flutter run -d chrome --web-port=5173
```

Then access via `https://localhost:5173` (you may need to accept self-signed certificate warning).

Alternatively, use a tool like `ngrok` to expose your local server:

```bash
ngrok http 5173
```

Then update Auth0 Dashboard with the ngrok URL.

## Production Deployment

Before deploying to production:

1. Update `.env` with production Auth0 domain and credentials
2. Update Allowed Callback URLs in Auth0 Dashboard to your production domain
3. Update Allowed Web Origins in Auth0 Dashboard
4. Ensure HTTPS is enabled on production domain
5. Run: `flutter build web --release`
6. Deploy the contents of `build/web` to your hosting provider

## Additional Resources

- [Auth0 Flutter Documentation](https://auth0.com/docs/get-started/authentication-and-authorization/web-apps)
- [Flutter Web Documentation](https://flutter.dev/multi-platform/web)
- [PKCE Documentation](https://tools.ietf.org/html/rfc7636)
- [OAuth 2.0 Implicit Flow](https://tools.ietf.org/html/rfc6749#section-4.2)
