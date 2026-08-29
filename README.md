# fabric-assets

Versioned strict-contract catalogs, template material, and provenance for
[Fabric](https://github.com/inovacc/fabric).

This repository is intentionally separate from Fabric's compiler behavior.
Fabric pins a reviewed commit as a submodule and will embed an approved bundle
at build time; normal `init`, `validate`, `plan`, and `generate` operations do
not fetch this repository or any upstream metadata.

## What is here now

- `bundles/fabric-assets-v1.json`: the immutable bundle identity and digest.
- `catalog/`: the curated Spring Boot and .NET dependency allow-list.
- `contract/`: the v1 JSON schema.
- `tools/normalize-and-validate.ps1`: fail-closed semantic validation.
- `refresh/`: refresh state and upstream provenance records.

The catalog is groundwork for the four designed profiles—Spring Boot Maven,
Spring Boot Gradle, ASP.NET Core minimal API, and ASP.NET Core controller API.
Their templates, golden fixtures, and refresh workflow are not present yet.

## Validate a bundle

From this repository root:

```powershell
pwsh -NoProfile -File tools/normalize-and-validate.ps1 -Root .
pwsh -NoProfile -File tests/validate-assets.ps1 -Root .
```

The validator rejects unknown or dynamic dependencies, unsafe/colliding
template output paths, unknown tokens, invalid ownership classes, malformed
template hashes, and manifest-digest mismatches. There is no force mode.

## Update policy

Only curated entries in `catalog/curated-allow-list.json` may appear in a
bundle. Upstream discovery sources are evidence for an update, not automatic
input to a released bundle. Each accepted update must carry provenance and a
recomputed manifest digest, receive human review, and be explicitly pinned by
Fabric.
