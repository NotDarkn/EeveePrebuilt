# EeveeReincarnatedIPA
**Maintainers**: [**jaydenjcpy**](https://github.com/jaydenjcpy) & [**faroukbmiled**](https://github.com/faroukbmiled) - **Uploader:** [**NotDarkn**](https://github.com/notdarkn) <br />
**Last Update:** `6/7/26` - **Current Version** `9.1.48`

I created this repository mainly so I could create myself prebuilt binaries of [EeveeSpotifyReincarnated](https://github.com/jaydenjcpy/EeveeSpotifyReincarnated) without needing to wait for another repository to do it for me (_or perhaps losing out on some changes_). ~~Additionally, the other prebuilt binary repository, [EeveeIPA](https://github.com/estrogencat/EeveeIPA), just did **NOT** work when I tried to sideload using tools such as Sideloadly, so building it myself was the next best option.~~ (*this should be fixed now, ty @estrogencat :3)

## Download
The latest prebuilt EeveeReincarnatedIPA binaries can be found [here](https://github.com/NotDarkn/EeveeReincarnatedIPA/releases/latest).

## How I Build
1. Obtain the latest Spotify IPA from the [Decrypted iOS IPA App Store](https://armconverter.com/decryptedappstore/us).
2. Upload the IPA to a temporary file hosting website for GitHub Actions to obtain from. (_in this case, I use [catbox.moe](https://catbox.moe/)_)
3. Go into "[Actions](https://github.com/NotDarkn/EeveeReincarnatedIPA/actions)" → "Build IPA (NO PATCH)" & "BUILD IPA (PATCHED)" → "Run Workflow" → Insert the URL<sup>1</sup> from step 2 and run the workflow.
4. After it finishes, download the artifacts, test<sup>2</sup> them, and upload them into a GitHub release.

<sup>1. If EeveeSpotifyReincarnated updates but Spotify hasn't, then I **reuse** the Spotify IPA I uploaded before to build IPAs again.</sup><br />
<sup>2. These prebuilt binaries are tested using an **iPhone 13 mini** running **iOS `26.5`** with a **Free Developer Account**.<sup>3</sup></sup><br />
<sup>3. I am unable to test patched binaries which in return means I **cannot** verify if they successfully install or launch.

---

![Banner](Images/banner.png?)
This tweak makes Spotify think you have a Premium subscription, granting free listening, just like Spotilife, and provides some additional features like custom lyrics.

> [!NOTE]
> The original EeveeSpotify repository was disabled due to a [DMCA takedown](https://github.com/github/dmca/blob/master/2025/08/2025-08-14-spotify.md). This repository will not contain IPA packages in the repo itself.

## Custom Lyrics Support

**Spotify 9.1.48+** - Full custom lyrics functionality is available with the following providers:

- **Musixmatch**
- **PetitLyrics**
- **LRCLIB**
- **Genius**

## The History

In January 2024, Spotilife, the only tweak to get Spotify Premium, stopped working on new Spotify versions. [whoeevee](https://github.com/whoeevee) decompiled Spotilife, reverse-engineered Spotify, intercepted requests, etc., and created this tweak.

In December 2025, whoeevee, the maintainer of the EeveeSpotify tweak at the time, announced he'll be discontinuing the tweak because of the burden of keeping up with Spotify's constantly changing architectures. Soon after, [Meep1](https://github.com/Meeep1), forks the original Eevee repo and continues to develop the tweak to support newer Spotify versions, under the project name EeveeSpotiyRevivedPublic.

In  March 2026, the latest EeveeSpotifyRevivedPublic release, v9.1.28, users experienced constant logging out issues and reported to Skye, however, at the time of this README.md written, EeveeSpotifyRevivedPublic hasn't released any newer updates. During March, I've been constantly annoyed by the logout issue and decided to take matters into my own hands and forked EeveeSpotifyRevivedPublic and fixed the logout issue, which will eventually lead to the creation of this repository, which will be continuing the legacy of EeveeSpotify for newer versions of Spotify.



## Restrictions

Please refrain from opening issues about the following features, as they are server-sided and will **NEVER** work:

- Very High audio quality
- Native playlist downloading (you can download podcast episodes though)
- Jam (hosting a Spotify Jam and joining it remotely requires Premium; only joining in-person works)
- AI DJ/Playlist
- Spotify Connect (When using Spotify Connect, the device will act as a remote control and stream directly to the connected device. This is a server-sided limitation and is beyond the control of EeveeSpotify, so it will behave as if you have a Free subscription while using this feature.)

## [Common Issues](https://github.com/jaydenjcpy/EeveeSpotifyReincarnated/blob/Master/common_issues.md)
Please check out the hyperlink above before opening an issue


## Lyrics Support

EeveeSpotify replaces Spotify monthly limited lyrics with one of the following four lyrics providers:

- Genius: Offers the best quality lyrics, provides the most songs, and updates lyrics the fastest. Does not and will never be time-synced.

- LRCLIB: The most open service, offering time-synced lyrics. However, it lacks lyrics for many songs.

- Musixmatch: The service Spotify uses. Provides time-synced lyrics for many songs, but you'll need a user token to use this source. To obtain the token, download Musixmatch from the App Store, sign up, then go to Settings > Get help > Copy debug info, and paste it into EeveeSpotify alert. You can also extract the token using MITM.

- PetitLyrics: Offers plenty of time-synced Japanese and some international lyrics.

If the tweak is unable to find a song or process the lyrics, you'll see a "Couldn't load the lyrics for this song" message. The lyrics might be wrong for some songs when using Genius due to how the tweak searches songs. While I've made it work in most cases, kindly refrain from opening issues about it.

## How It Works

EeveeSpotify intercepts Spotify requests to load user data, deserializes it, and modifies the parameters in real-time. This method works incredibly stable across supported Spotify versions.

The tweak also sets `trackRowsEnabled` to `true`, allowing you to see track rows and liked tracks on artist pages just like with Premium.

## Installation

For sideloaded IPAs, we recommend using **SideStore** or certificate-based signing tools like **Ksign** for best compatibility.

To open Spotify links in sideloaded app, use [OpenSpotifySafariExtension](https://github.com/BillyCurtis/OpenSpotifySafariExtension). Remember to activate it and allow access in Settings > Safari > Extensions.

## Credits
Thanks for all of the community's support, also, thanks to all the devs who worked along with me to revive this project Go check the other dev's out:

[Ryuk](https://github.com/faroukbmiled) - True Shuffle, App Icon, Support for Spotify v9.1.46 and above 

[Mod-4](https://github.com/M0d-4) - Custom Lyrics, iPadUI fix 

[estrogencat](https://github.com/estrogencat) - Icon Fixes 

[Skye](https://github.com/Meeep1) - EeveeSpotifyRevivedPublic, the base of this project 

[whoeevee](https://github.com/whoeevee) - EeveeSpotify & EeveeSpotifyReborn, where all this started




