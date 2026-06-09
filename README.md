![Banner](https://github.com/NotDarkn/EeveeReincarnatedIPA/blob/Master/Images/banner2.png)
---
**Maintainers**: [**jaydenjcpy**](https://github.com/jaydenjcpy) & [**faroukbmiled**](https://github.com/faroukbmiled) - **Uploader:** [**NotDarkn**](https://github.com/notdarkn) <br />
**Last Update:** `6/8/26` (MM/DD/YY) - **Spotify Version:** `9.1.48`

I created this repository mainly so I could create myself prebuilt binaries of [EeveeSpotifyReincarnated](https://github.com/jaydenjcpy/EeveeSpotifyReincarnated) without needing to wait for another repository to do it for me (_or perhaps losing out on some changes_).

<sup>This repository is inspired from [@estrogencat](https://github.com/estrogencat)'s [EeveeIPA](https://github.com/estrogencat/EeveeIPA) repository. Her prebuilts didn't let me sideload with [Sideloadly](https://sideloadly.io/)<sup>1</sup>, so I made this. <br /><sup>1. She've since fixed it as told in her [README.md](https://github.com/estrogencat/EeveeIPA#eeveespotifyreincarnated).</sup></sup>

## Download
The latest prebuilt EeveeReincarnatedIPA binaries can be found [here](https://github.com/NotDarkn/EeveeReincarnatedIPA/releases/latest).

## How I Build
1. Obtain the latest Spotify IPA from the [Decrypted iOS IPA App Store](https://armconverter.com/decryptedappstore/us).
2. Upload the IPA to a temporary file hosting website for GitHub Actions to obtain from. (_in this case, I use [catbox.moe](https://catbox.moe/)_)
3. Go into "[Actions](https://github.com/NotDarkn/EeveeReincarnatedIPA/actions)" → "Build IPA (NO PATCH)" & "BUILD IPA (PATCHED)" → "Run Workflow" → Insert the URL<sup>1</sup> from step 2 and run the workflow.
4. After it finishes, download the artifacts, test<sup>2</sup> them, and upload them into a GitHub release.

<sup>1. If EeveeSpotifyReincarnated updates but Spotify hasn't, then I **reuse** the Spotify IPA I uploaded before to build IPAs again.</sup><br />
<sup>2. These prebuilt binaries are tested using an **iPhone 13 mini** running **iOS `27.0`** with a **Free Developer Account** through **Sideloadly**.<sup>3</sup></sup><br />
<sup>3. I am unable to test patched binaries which in return means I **cannot** verify if they successfully install or launch.

## Credits

[Ryuk](https://github.com/faroukbmiled) - True Shuffle, App Icon, Support for Spotify v9.1.46 and above 

[Mod-4](https://github.com/M0d-4) - Custom Lyrics, iPadUI fix 

[estrogencat](https://github.com/estrogencat) - Icon Fixes 

[Skye](https://github.com/Meeep1) - EeveeSpotifyRevivedPublic, the base of this project 

[whoeevee](https://github.com/whoeevee) - EeveeSpotify & EeveeSpotifyReborn, where all this started
