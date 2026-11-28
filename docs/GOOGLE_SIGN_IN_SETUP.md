# Google Sign-In setup

The Flutter app ships with the real `google_sign_in` plugin wired up, but a
build only uses it once it has been told which Google Cloud project it belongs
to. Until then it falls back to the local stand-in and says so on the welcome
screen.

This document is the whole path from nothing to a working sign-in. It takes
about fifteen minutes, needs a Google account, and has to be done once per
project — not once per developer.

## Why the app does not simply ship with credentials

An OAuth client is tied to a project, a package name and a signing key. The
identifier itself is not a secret (it travels in every sign-in request), but
committing one would mean every clone of this repository shared one Google
Cloud project, and that the app only worked for whoever held that project's
keys. So the identifier arrives at build time and the repository stays usable
by anyone.

---

## What you are creating

Two OAuth clients in one Google Cloud project:

| Client | Why it exists | Does Dart name it? |
|---|---|---|
| **Android** | Ties the app's package name and signing fingerprint to the project. Without it Google refuses the request. | No |
| **Web** | The audience of the ID token. Android's Credential Manager issues a token *for a server*, and this client is that server. | Yes — as `GOOGLE_SERVER_CLIENT_ID` |

The web client is the confusing part: this is an Android app with no web
build, and the identifier the app passes is nonetheless the web one. That is
how Credential Manager works, and passing the Android client id instead is the
single most common reason sign-in fails with a "cancelled" that nobody
cancelled.

---

## Step 1 — a Google Cloud project

1. Open <https://console.cloud.google.com/> and create a project. Any name;
   `LifePilot Finance` is the obvious one.
2. Note the project — everything below happens inside it.

## Step 2 — the OAuth consent screen

Under **APIs & Services → OAuth consent screen**:

1. User type **External**, unless the accounts are all in one Google Workspace
   domain.
2. Fill in the app name, a support email and a developer email. Nothing else
   is required while the app is in testing.
3. Scopes: leave the defaults. The app asks for identity only — no Drive, no
   Gmail, no contacts — so there is nothing to add and nothing to justify.
4. **Add every account that will sign in as a test user.** While the consent
   screen is in *Testing*, Google refuses any account not on that list, and
   the refusal arrives in the app as a sign-in that fails for no visible
   reason. This trips up more first attempts than anything else here.

## Step 3 — the Android OAuth client

You need the SHA-1 fingerprint of the key that signs the build. For a debug
build that is the shared debug keystore Android created on your machine:

```bash
keytool -list -v -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

On Windows the keystore is at `%USERPROFILE%\.android\debug.keystore`, and
`keytool` ships with Android Studio's bundled JDK:
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

Copy the `SHA1:` line. Then, under **APIs & Services → Credentials → Create
credentials → OAuth client ID**:

- Application type: **Android**
- Package name: `com.lifepilot.lifepilot_finance`
- SHA-1: the fingerprint you just printed

The debug fingerprint differs per machine, so each developer adds their own.
A release build has its own key and its own fingerprint — see *Release builds*
below.

## Step 4 — the web OAuth client

Create a second client, application type **Web application**. It needs no
redirect URI: nothing here runs in a browser, and the client exists only to
give the ID token an audience.

Copy its client id. It looks like
`123456789012-abc123def456.apps.googleusercontent.com`.

## Step 5 — run the app with it

```bash
cd mobile
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<the web client id>
```

The welcome screen tells you which provider you got: if the line *"Demo
sign-in: no Google account is contacted"* is still under the button, the
define did not reach the build.

To keep the define out of your fingers on every run, put it in a launch
configuration — VS Code's `.vscode/launch.json` takes `toolArgs`, Android
Studio has a *Additional run args* field — or use a
[`--dart-define-from-file`](https://dart.dev/tools/dart-compile) JSON file,
which is also the right home for it in CI.

---

## Verifying it actually works

1. Launch the app. The welcome screen should have no demo note.
2. Tap **Continue with Google**. The system account sheet appears — that
   sheet is Android's, not Flutter's, so seeing it at all means the Android
   client matched.
3. Pick an account. You land on the profile step of setup with your real name
   and email filled in, the email marked **From Google** and read-only.
4. Open **Profile & settings → Security & privacy**. It should say *Google*
   and name the keystore rather than describing a stand-in.
5. Relaunch the app. You go straight to the dashboard, and the credential is
   silently refreshed in the background.

### When it does not

The app turns every provider failure into a sentence on the welcome screen.
These are what they mean:

| What the screen says | What is actually wrong |
|---|---|
| *This build of LifePilot is missing its Google sign-in setup* | `clientConfigurationError`. The define is absent or malformed. |
| *Google sign-in is unavailable on this device* | `providerConfigurationError`. No Google Play services — a plain AOSP emulator image, typically. Use a *Google APIs* or *Google Play* image. |
| *Sign-in cancelled*, without anyone cancelling | Android reports several configuration problems as a cancellation and the plugin cannot tell them apart. Check, in order: the SHA-1 matches the key that signed **this** build; the package name is exactly `com.lifepilot.lifepilot_finance`; the define carries the **web** client id, not the Android one; the account is on the test-user list. |
| *Sign-in stopped before it finished* | `interrupted`. Usually the network. |

The log is more specific than the screen is, on purpose — a user in a shop
does not need to read `serverClientId`. Run with `flutter run` attached and
look for the `Google sign-in:` line, which carries the SDK's own description.

---

## Release builds

A release APK is signed with a different key, so its SHA-1 is different and
Google will reject it until that fingerprint is registered too. Add a second
Android OAuth client (or add the fingerprint to the existing one) for the
release key, and the Play App Signing key as well if the app is distributed
through Play — Play re-signs the upload, and the fingerprint that reaches
Google at runtime is Play's, which the console shows under *App integrity*.

Sign-in working in debug and failing in release is almost always this.

## iOS is not set up

There is an `ios/` directory because `flutter create` makes one, but nothing
in it has been configured for sign-in and no iOS build is in the plan:
LifePilot is Android-first. `AuthConfig` already carries an
`GOOGLE_IOS_CLIENT_ID` define so that the one place that reads configuration
stays the one place, and it is passed to the plugin as `clientId`, but an iOS
build would also need:

- an **iOS** OAuth client in the same project, with the bundle id;
- the reversed client id (`com.googleusercontent.apps.123-abc`) added to
  `CFBundleURLTypes` in `Info.plist`, because the flow returns through a URL
  scheme.

Half-filling the plist now would leave a placeholder that looks configured and
is not, so it is left alone until there is an iOS build to test it with.

## The other way to configure Android

If you would rather use Firebase, enable Google sign-in there and drop the
generated `google-services.json` into `mobile/android/app/`. The identifiers
then come from that file instead of from Dart, so there is no client id to
define — but the app still has to be told to use the real provider, since it
decides by looking for the define:

```bash
flutter run --dart-define=SIGN_IN_PROVIDER=google
```

The file must contain a web OAuth client (an `oauth_client` entry with
`client_type: 3`), or Android fails with "serverClientId must be provided".

## Keeping the stand-in

`--dart-define=SIGN_IN_PROVIDER=mock` forces the local provider even on a
machine that has credentials. That is how the cancelled and failed states stay
reachable — long-press the brand mark on the welcome screen to choose which
one the next attempt produces. A real provider will not fail to order.

---

## What the app does with the credential

The ID token is written to `flutter_secure_storage` — the Android keystore —
under `auth.google.idToken`, never to the preferences file that holds the rest
of the app's state. It is refreshed in the background at every launch, because
an ID token is valid for about an hour, and it is deleted on sign-out.

Nothing reads it yet. It is a signed claim about who the user is, and the
thing that should check that signature is the backend that will accept it; an
app verifying its own credential proves nothing. Obtaining and keeping it is
the part that is hard to retrofit, which is why it happens now.

The secure store is excluded from Android backup and device transfer
(`mobile/android/app/src/main/res/xml/backup_rules.xml`): the encryption key
cannot leave the phone, so a restored copy would be an undecryptable blob. A
user who moves to a new phone signs in again, and their transactions, budgets
and goals come across as usual.
