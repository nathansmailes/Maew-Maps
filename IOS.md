# Building the iPhone app

The iPhone app bundles the same `index.html` as the website, using Capacitor.
Location uses the phone's native location service; photos use the native camera / library picker.

On the Mac (needs Xcode and Node.js):

```sh
npm install
npm run ios      # copies the web app in, syncs plugins, opens Xcode
```

In Xcode: pick the **App** target → **Signing & Capabilities** → choose your team,
then press ▶ with your iPhone plugged in. To upload: **Product → Archive → Distribute App**.

Whenever `index.html` changes, run `npm run ios` again before building.
