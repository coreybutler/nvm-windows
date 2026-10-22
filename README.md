<a href="https://trendshift.io/repositories/4201" target="_blank"><img src="https://trendshift.io/api/badge/repositories/4201" alt="nvm-windows | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

# <sub><img src="https://github.com/nvm-windows.png?s=50" width="32" align="bottom" /></sub> NVM for Windows

The <a href="https://docs.microsoft.com/en-us/windows/nodejs/setup-on-windows">Microsoft</a>/<a href="https://cloud.google.com/nodejs/docs/setup#installing_nvm">Google</a> recommended Node.js version manager for millions of Windows developers. 

> [!IMPORTANT]
> **You may already have NVM for Windows.** [Microsoft Zenith](https://blogs.windows.com/windowsdeveloper/2026/09/04/announcing-project-zenith-the-ready-to-code-windows-experience/) preconfigures NVM, starting with AMD Ryzen AI Halo devices. More devices from OEM and silicon partners will be available in the coming months.  

<details>
<summary><b>NVM for Windows is not the same thing as nvm!</b> (expand for details)</summary>

_The original [nvm](https://github.com/nvm-sh/nvm) is a completely separate project for Mac/Linux only._ This project uses an entirely different philosophy and is not just a clone of nvm.
</details>

<!-- nvm-readme-release-badges:start -->
[![Install Stable Version](https://img.shields.io/badge/-Install%20Stable%20Version-%2322A6F2)](https://github.com/nvm-windows/nvm/releases/tag/v2.0.1) [![Prerelease](https://img.shields.io/badge/Prerelease-v2.1.0--beta.1-1?style=social)](https://github.com/nvm-windows/nvm/releases/tag/v2.1.0-beta.1) ![Downloads](https://img.shields.io/github/downloads/nvm-windows/nvm/total?label=Downloads&style=social) [![Twitter URL](https://img.shields.io/twitter/url?style=social&url=https%3A%2F%2Ftwitter.com%2Fintent%2Ftweet%3Fhashtags%3Dnodejs%26original_referer%3Dhttp%253A%252F%252F127.0.0.1%253A91%252F%26text%3DNVM%2520for%2520Windows%2520v2%2520is%2520available%21%26tw_p%3Dtweetbutton%26url%3Dhttps%253A%252F%252Fnvm-windows.com)](https://twitter.com/intent/tweet?hashtags=nodejs&original_referer=http%3A%2F%2F127.0.0.1%3A91%2F&text=NVM%20for%20Windows%20v2%20is%20available.&tw_p=tweetbutton&url=https%3A%2F%2Fnvm-windows.com)
<!-- nvm-readme-release-badges:end -->

<table>
  <tr>
    <td>
      <h3>🚀 Version 2 is available</h3>
      <p>NVM for Windows has been <a href="https://medium.com/@goldglovecb/why-we-rewrote-nvm-for-windows-3b6fa5be3e7f?sharedUserId=goldglovecb">fully rewritten</a> for modern workflows.</p>
      <p><strong><a href="https://docs.nvm-windows.com/features/newv2">Explore what’s new →</a></strong></p>
    </td>
  </tr>
  <tr>
    <td>
      <h3>🏢 Introducing Certified Builds</h3>
      <p>Deploy NVM for Windows in controlled environments with commercial Certified Builds and optional add-ons:</p>
      <ul>
        <li><strong>IT-managed deployment</strong> with MSI and Intune</li>
        <li><strong>Centralized policy enforcement</strong></li>
        <li><strong>Auditable operations</strong> with advanced logging</li>
        <li><strong>Supply-chain confidence</strong> with verifiable trust artifacts</li>
      </ul>
      <p><strong><a href="https://nvm-windows.com/certified">Explore Certified Builds →</a></strong></p>
    </td>
  </tr>
</table>

## Resources

- [Official Website](https://nvm-windows.com)
- [Documentation](https://docs.nvm-windows.com)
- [Announcements](https://github.com/orgs/nvm-windows/discussions/categories/announcements)
- [Why We Rewrote NVM for Windows](https://medium.com/@goldglovecb/why-we-rewrote-nvm-for-windows-3b6fa5be3e7f?sharedUserId=goldglovecb)

## Features

> [!IMPORTANT]
> **Community Edition installers are now code-signed as of v2.0.0-hotfix.2.**

|Feature|Description|
|:-|:-|
|Compatibility<br/><br/><br/>|&bull; No mandatory administrator privileges.<br/>&bull; Shim mode - no symlinks, fast (written in Zig).<br/>&bull; Link mode - Zero-latency, junctions with symlink fallback.|
|Automation<br/><br/><br/>|&bull; Per-directory version switching (pinning).<br/>&bull; Auto-install missing versions.<br/>&bull; Auto-install default global modules.|
|Speed<br/><br/><br/><br/>|&bull; Parallel (multiple) simultaneous installations.<br/>&bull; Smaller downloads (7z).<br/>&bull; Native extraction.<br/>&bull; Caching.|
|Native&nbsp;Integrations<br/><br/><br/><br/>|&bull; Windows Apps<br/>&bull; Logging (Windows Event Viewer)<br/>&bull; Windows Registry<br/>&bull; Desktop Notification Center|
|Customization<br/><br/><br/>|&bull; User-defined aliases.<br/>&bull; User-defined default global modules.<br/>&bull; Configure local (air-gapped) downloads.|

### Certified Builds

Commercial **Certified Builds** are now available for controlled environments. [Learn more](https://nvm-windows.com/certified).

Not sure which edition is right for you? See [Choosing a Build](https://docs.nvm-windows.com/guide/builds/).

|Feature|Description|
|:-|:-|
|IT-Managed Installation<br/><br/>|&bull; Windows-protected installation directory<br />&bull; Administrator-controlled deployment and device management|
|Installers<br/><br/>|&bull; MSI/MST<br />&bull; Microsoft Intune|
|Advanced Logging ⭐<br/><br/><br/><br/>|&bull; Fully auditable<br />&bull; Structured<br />&bull; Dedicated Event Source<br />&bull; Native SIEM integration|
|Policy Enforcement ⭐<br/><br/><br/><br/><br/>|&bull; Active Directory/Entra integration<br/>&bull; Restrict Node.js versions/ranges (e.g. no EOL versions, LTS only, etc.)<br/>&bull; Control nvm-windows, Node/npm/npx settings<br/>&bull; Advanced proxy (IWA, WPAD/PAC) support<br />&bull; Private Node.js download mirror|
|Trust Artifacts ⭐<br/><br/><br/><br/>|&bull; SBOM + AI-BOM<br />&bull; SLSA Provenance<br />&bull; SAST<br />&bull; VEX Reports|

⭐ = Add-on package

## :pray: Thanks

Thanks to everyone who has submitted issues on and off GitHub, made suggestions, and generally helped make this a better project. Special thanks and the full contributor list is available **[here](THANKS.md)**.
