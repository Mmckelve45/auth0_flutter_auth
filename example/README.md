# Auth0 Flutter Auth - Mobile Example App

This is a comprehensive example of how to integrate Auth0 authentication into a Flutter mobile application (iOS/Android) using the `auth0_flutter_auth` package.

## Features

- OAuth 2.0 + PKCE authentication flow
- Automatic callback handling with GoRouter
- Secure token storage and refresh
- User profile display
- Token refresh capability
- Logout functionality

## Prerequisites

- Flutter SDK (latest stable version)
- iOS 12+ and/or Android API 21+
- Auth0 account and application
- Xcode (for iOS development)
- Android Studio (for Android development)

## Setup Instructions

### 1. Configure Auth0 Application

1. Go to [Auth0 Dashboard](https://manage.auth0.com)
2. Create or select your application
3. In **Settings**, add the callback URL:
   ```
   YOUR_SCHEME://callback
   ```
   (Replace `YOUR_SCHEME` with your app identifier, e.g., `com.example.auth0demo://callback`)

4. Add the logout URL:
   ```
   YOUR_SCHEME://logout
   ```

5. In **Settings** → **Advanced**, enable **Refresh Token Rotation**

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

### 3. Platform-Specific Configuration

#### iOS Setup

1. Open `ios/Runner/Info.plist` and add URL scheme:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>YOUR_SCHEME</string>
       </array>
     </dict>
   </array>
   ```

#### Android Setup

1. Update `android/app/src/main/AndroidManifest.xml`:
   ```xml
   <activity
       android:name="com.auth0.flutter_auth.CallbackActivity"
       android:scheme="YOUR_SCHEME"
       android:exported="true">
       <intent-filter>
           <action android:name="android.intent.action.VIEW" />
           <category android:name="android.intent.category.DEFAULT" />
           <category android:name="android.intent.category.BROWSABLE" />
           <data
               android:scheme="YOUR_SCHEME"
               android:host="callback" />
       </intent-filter>
   </activity>
   ```

2. Update `android/app/build.gradle`:
   ```gradle
   android {
       compileSdkVersion 34
       // ... other config
   }
   ```

### 4. Install Dependencies

```bash
flutter pub get
```

## Running the App

### iOS
```bash
flutter run -d iPhone
```

### Android
```bash
flutter run -d emulator-5554
```
(Replace `emulator-5554` with your device name)

## App Structure

### Screens

- **HomeScreen**: Initial login screen with Auth0 login button
- **CallbackScreen**: Handles OAuth redirect and token exchange
- **ProfileScreen**: Displays user information, token details, and logout button

### Key Files

- `lib/main.dart`: Application entry point and router configuration
- `lib/screens/home_screen.dart`: Login UI
- `lib/screens/callback_screen.dart`: Callback handler
- `lib/screens/profile_screen.dart`: User profile display
- `.env`: Environment variables (create from `.env.example`)

## Authentication Flow

1. User taps "Login with Auth0" on HomeScreen
2. App opens Auth0 login page
3. User authenticates and consents
4. Auth0 redirects to callback URL
5. App captures callback and exchanges auth code for tokens
6. Tokens are securely stored
7. User is navigated to ProfileScreen
8. ProfileScreen displays user information from ID token

## Token Management

The example demonstrates:

- **Access Token**: Used for API requests (if needed)
- **Refresh Token**: Used to obtain new access tokens when they expire
- **ID Token**: Contains user profile information
- **Token Refresh**: Automatic refresh when token expires

## Logout

When user taps logout:
1. Tokens are cleared from secure storage
2. User is redirected to Auth0 logout endpoint
3. App navigates back to HomeScreen

## Troubleshooting

### Callback not working
- Verify callback URL in Auth0 Dashboard matches your scheme
- Check platform-specific URL scheme configuration
- Ensure CallbackActivity is properly configured on Android

### Token issues
- Clear app data and re-authenticate
- Verify Refresh Token Rotation is enabled in Auth0
- Check that `.env` file has correct credentials

### iOS build issues
- Run `flutter clean` and `flutter pub get`
- Delete `ios/Pods` and run `flutter run` again

## Additional Resources

- [Auth0 Flutter Documentation](https://auth0.com/docs/get-started/authentication-and-authorization/mobile-apps/native-mobile-apps)
- [Flutter Documentation](https://flutter.dev)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
