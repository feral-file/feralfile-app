# Feral File: the way to collect art


## About

### [Feral File](https://feralfile.com/) is the place to experience digital art today.

Visit curated exhibitions of world-class, software-based art, interact with dynamic digital works, and organize your personal digital art collection directly in the app. You can share and enjoy all artwork found in the app with friends and family by Streaming to any compatible screen.

Co-create a [MoMA Postcard](https://www.moma.org/calendar/exhibitions/5618) and experiment with borderless collaboration and creativity.


</br>
</br>


The **Feral File** app enhances the digital experience, increasing the ways people can share, organize, explore, and live with software-based artwork.


#### Explore Feral File Exhibitions

- Each exhibition on **Feral File** begins with the curator. World-class artists collaborate with visionary curators to create and exhibit artworks around a single, ambitious theme.

- Exhibitions never close on **[feralfile.com](https://feralfile.com/)**. Soon, all exhibitions will be viewable and streamable on the **Feral File** app. For now, the current exhibition is on view.


#### Live with digital art

- Stream digital artwork to any compatible screen. Share and enjoy your favorite pieces with family, friends, and colleagues at home and in the office.

- For interactive works, your mobile device becomes the remote control. Use the keyboard, experiment with the artist’s commands, and dive into the immersive world of software-based art.


#### Organize

- Consolidate collected digital art across blockchains (Ethereum and Tezos)

- Create collections within your collection.

- The app classifies artwork into 3 categories: Still, Video, Interactive.


#### Share

- Co-create a digital chain letter with [MoMA Postcard](https://www.moma.org/calendar/exhibitions/5618). This experiment in borderless collaboration and creativity explores ways individuals, groups, and institutions can make and own digital goods.

- The “View existing address” feature allows you to see other collections and share yours with friends.


</br>
</br>


Bitmark started with the idea of building tools to help individuals and institutions secure digital property rights. Feral File, an online gallery co-founded by Casey Reas, applies this vision to art made with software, helping artists and collectors secure the property rights to their artwork. Visit feralfile.com and experience world-class digital art in-situ. The **Feral File** app goes beyond ownership and provides dynamic ways to engage with digital art on your personal devices, in your home, and across the world.

</br>

![all in one](https://github.com/bitmark-inc/feralfile-app/assets/61187455/a63402ea-3949-4188-b9dd-c26c7457952b)



## Getting Started

1. Install [Flutter](https://flutter.dev)
2. Install Android SDK & Xcode (using `flutter doctor` to see all your tools and dependencies are fully installed).
2. Clone the repo
3. Initialize submodule by running; `git submodule update --init --recursive`
- If you don't want to clone the auto-test package, simply run: `git -c submodule.auto-test.update=none submodule update --init --recursive`
4. Initialize the config file. `cp .env.example .env`
- Contact with Feral File app development team for development env.
5. Initialize the secret config file. `cp .env.secret.example .env.secret`
- There are credentials information. You may need to provide your own credentials.Contact with Feral File app development team for consultation.
6. Run ./script/encrypt_secrets.sh <-entropy-> to generate the encrypted secrets file.
- <-entropy-> is a random string. You can type a random string like akhrdsgl4893tynk3iu4y8hf
- You only need to run this script again when you want to update .env.secret.
7. Run `flutter run --flavor inhouse` to run **Feral File** app development on the connected device.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://flutter.dev/docs/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://flutter.dev/docs/cookbook)

For help getting started with Flutter, view our
[online documentation](https://flutter.dev/docs), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Status - Released
- [App Store](https://apps.apple.com/us/app/feral-file/id1544022728)
- [Google Play](https://play.google.com/store/apps/details?id=com.bitmark.autonomy_client&pli=)

[Release Notes](https://github.com/bitmark-inc/feral-file-docs/blob/main/app/release_notes/production/changelog.md)

## Contributing

We welcome contributions of any kind including new features, bug fixes, and documentation improvements. Please first open an issue describing what you want to build if it is a major change so that we can discuss how to move forward. Otherwise, go ahead and open a pull request for minor changes such as typo fixes and one liners.

### Discussions:
Join us on [Discord](https://discord.gg/3BBkrjS4n7) to give feedback and help us shape new features.

## License
This project is licensed under the BSD-2-Clause Plus Patent License. See the [LICENSE](LICENSE) file for details.
