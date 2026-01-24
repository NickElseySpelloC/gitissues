# GitIssues

This is a native macOS SwiftUI application that you can use to create and edit GitHub issues across multiple repositories.

It's still very much a work in progress, but it's already better that some of the alternatives I've tried and rejected (Taska; Gitscout; GitKraken; etc.).

This app only intended for issue management, it won't help you with other aspects of Git / GitHub.

## Installing

For now, you'll need to clone this repo and build the app on your Mac. I've tested on an Intel Mac (running Sequoia 15.7) and an Apple Silicon mac (running Tahoe 26.1). Just build the app and copy GitIssues.app to your Applications folder.

## Initial Setup

GitIssues needs a GitHub OAuth token to allow it to integrate with the GitHub APIs. For now, you will need to create this token yourself (this will be improved in the future -see [Improve OAuth scheme for production deployment](https://github.com/NickElseySpelloC/gitissues/issues/4) ). Create your token as follows:

1. Login to GitHub and go to [You > Settings... > Developer Settings > OAuth Apps](https://github.com/settings/developers)
2. Click **New OAuth App**.
3. Configure as follows:
   - **Application Name**: GitIssues
   - **Homepage URL**: Any URL will do
   - **Authorization callback URL**: gitissues://oauth-callback
4. Click **Register Application**
5. Make a new of the **Client ID**.
6. Click **Generate a new client secret** and then make a note of the client secret.

Now go back to the GitIssues app and go to the **Settings...** page. Enter the Client ID and Client Secret there and click Save Changes

## Known Limitations

- The description and comment fields support markdown formatting, but these controls are very basic. 
- See https://github.com/NickElseySpelloC/gitissues/issues for other planned enhancements and bug fixes.