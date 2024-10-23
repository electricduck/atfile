<h1 align="center">
    ATFile
</h1>

<p align="center">
    Store and retrieve files on a <a href="https://atproto.com/guides/glossary#pds-personal-data-server">PDS</a> (like <a href="https://bsky.app">Bluesky</a>)<br />
    <em>Written entirely in Bash Shell. No <span title="Deno is pretty cool tho">NodeJS</span> here!</em>
</p>

<p align="center">
    <strong>
        <a href="https://github.com/electricduck/atfile/releases/latest">⬇️ Get ATFile</a> &nbsp;|&nbsp;
        <a href="https://github.com/electricduck/atfile/issues/new">💣 Submit Issue</a>
    </strong>
</p>

<hr />

## ✨ Quick Start

```sh
curl -sSL https://raw.githubusercontent.com/electricduck/atfile/refs/heads/main/atfile-install.sh | bash
echo 'ATFILE_USERNAME="<your-atproto-username>"' > ~/.config/atfile.env  # e.g. jay.bsky.team, did:plc:oky5czdrnfjpqslsw2a5iclo
echo 'ATFILE_PASSWORD="<your-atproto-password>"' >> ~/.config/atfile.env
atfile help
```
