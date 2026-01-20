# GitIssues Setup Guide

## What's Been Completed

✅ Phase 1 Foundation:
- Xcode project structure created
- Directory structure organized (Models, Views, Services, etc.)
- Info.plist configured with OAuth URL scheme (gitissues://)
- Entitlements file created with sandbox and network permissions
- OAuth2Manager implemented for GitHub authentication
- TokenStorage implemented for secure Keychain storage
- LoginView created with authentication UI
- Main app updated to handle OAuth callbacks

## Next Steps

### 1. Add Project Files to Xcode

Open the project in Xcode and add the new files to your target:

1. Open `GitIssues/GitIssues.xcodeproj` in Xcode
2. Right-click on the `GitIssues` folder in the navigator
3. Select "Add Files to GitIssues..."
4. Navigate to `GitIssues/GitIssues/` and add:
   - `Authentication/` folder
   - `Views/Authentication/` folder
   - `Info.plist`
   - `GitIssues.entitlements`
5. Make sure "Copy items if needed" is unchecked
6. Make sure "GitIssues" target is checked
7. Click "Add"

### 2. Configure Info.plist and Entitlements in Build Settings

1. In Xcode, select the project in the navigator
2. Select the "GitIssues" target
3. Go to "Build Settings" tab
4. Search for "Info.plist"
5. Set "Info.plist File" to: `GitIssues/Info.plist`
6. Search for "Code Signing Entitlements"
7. Set "Code Signing Entitlements" to: `GitIssues/GitIssues.entitlements`

### 3. Add Swift Package Dependencies

Since SPM in Xcode projects works differently than standalone packages:

1. In Xcode, go to File → Add Package Dependencies
2. Enter: `https://github.com/evgenyneu/keychain-swift.git`
3. Click "Add Package"
4. Repeat for: `https://github.com/gonzalezreal/swift-markdown-ui`

Note: You may not need KeychainSwift since we implemented Keychain access directly. Only add if needed later.

### 4. Set Environment Variables for OAuth

You need to provide your GitHub OAuth credentials via environment variables:

**Option A: Xcode Scheme (Recommended for Development)**
1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Run" on the left
3. Go to "Arguments" tab
4. Under "Environment Variables", click "+"
5. Add:
   - Name: `GITHUB_CLIENT_ID`, Value: `your_client_id_here`
   - Name: `GITHUB_CLIENT_SECRET`, Value: `your_client_secret_here`

**Option B: Shell Environment**
Add to your `~/.zshrc` or `~/.bashrc`:
```bash
export GITHUB_CLIENT_ID="your_client_id_here"
export GITHUB_CLIENT_SECRET="your_client_secret_here"
```

### 5. Build and Test OAuth Flow

1. In Xcode, select Product → Build (⌘B)
2. Fix any build errors (likely missing file references)
3. Run the app (⌘R)
4. Click "Sign in with GitHub"
5. Browser should open to GitHub authorization page
6. Approve the authorization
7. You should be redirected back to the app

### 6. Verify OAuth Callback

After authorization, the app should:
- Receive the callback URL (gitissues://oauth-callback?code=...)
- Exchange the code for an access token
- Store the token in Keychain
- Show ContentView (currently placeholder)

## Troubleshooting

### "Could not find GitIssuesApp"
- Make sure GitIssuesApp.swift is in the target membership

### "Cannot find 'OAuth2Manager' in scope"
- Add Authentication folder to Xcode project
- Check target membership for all Swift files

### "GitHub authorization fails"
- Verify CLIENT_ID and CLIENT_SECRET are set correctly
- Check that callback URL in GitHub OAuth app is: `gitissues://oauth-callback`

### "App doesn't receive callback"
- Verify Info.plist has CFBundleURLSchemes with "gitissues"
- Make sure Info.plist is properly linked in Build Settings

## What's Next

Once OAuth is working, we move to **Phase 2: API Layer**:
- Create data models (Issue, Repository, User, Label, Comment)
- Implement GraphQLClient for GitHub API
- Create GitHubAPIService
- Test fetching issues

See the full plan at: `~/.claude/plans/synthetic-munching-pebble.md`
