# Mac and Windows scope update — September 8, 2026

The owner withdrew Linux support after testing the interface. Current source
removes Linux insertion and Wayland handling, direct Linux integration crates,
Linux packaging configuration and release jobs. Future manifests contain Mac
and Windows installers only. Historical beta assets and checksums are preserved;
beta 4 release notes mark the Linux assets as unsupported previews.

The existing native Mac and Windows interfaces are retained. The website offers
Mac and Windows, treats Linux hints as unsupported, and keeps manual selection
available. Windows Smart App Control guidance is visible outside collapsed
help. This is a reported installation blocker, not a passed device test.

Validation:

- [Windows checks](https://github.com/leviackerman05/dictate/actions/runs/34253066732): passed for application changes at `b3be6c8`; UI build, eight core tests, verified-model synthetic recognition, and locked native compilation. Later changes are documentation and regenerated license notices only.
- [Mac checks](https://github.com/leviackerman05/dictate/actions/runs/34253066572): Swift tests and release build passed.
- Astro check: zero diagnostics. Three platform-policy tests, production build, and public Mac/Windows installer and manifest URL checks passed.
- Six local browser/platform simulations passed, including Linux falling back to both supported choices; manual switching, retired Linux URL parameters, no-JavaScript fallback, desktop/mobile and light/dark layouts, with no horizontal overflow or JavaScript errors. Screenshot review confirmed the visible Windows notice and two-tab layout.
- Live production browser test passed: Windows detection, CTA navigation, visible Smart App Control guidance, Mac switching, and no JavaScript errors. Homepage and download HTML have no Linux installer links.
- Two-artifact release-manifest fixture passed SHA-256 checks and rejected a missing Windows installer. Workflow YAML parsing, launcher shell syntax, and diff whitespace checks passed.

Website deployment: `dpl_D3K9XyAgacA3vtb27vec7UckqGoQ` from `b3be6c8`,
verified at https://dictate-macos.vercel.app/. Hosting remains the existing
Vercel Hobby project; CI used standard runners in the public GitHub repository.
No money was spent, and no signing account or paid service was enabled.

The owner’s Windows screenshot confirms that the unsigned installer was blocked
before startup because Smart App Control could not verify its publisher. No
“Run anyway” option exists for that dialog. See [the signing route under
consideration](../WINDOWS_SIGNING.md). Trusted signing and a fresh physical
Windows acceptance test are still outstanding; build success does not fix this.
