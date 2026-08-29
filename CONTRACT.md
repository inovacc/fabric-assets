# Fabric asset contract v1

Every published Fabric bundle is a JSON document under `bundles/` with
`contractVersion: "fabric-assets/v1"`. The bundle is immutable once its
`manifestDigest` is published.

The validator fails closed. It accepts only curated dependency IDs and exact
numeric versions, rejects ambiguous Windows paths and unknown render tokens,
and checks that each template hash is a lowercase SHA-256 digest. Generation
never consumes a catalog that did not pass this contract.

Run the local gate from this repository root:

```powershell
pwsh -NoProfile -File tools/normalize-and-validate.ps1 -Root .
```

`manifestDigest` is the SHA-256 of the compact UTF-8 JSON representation of
the bundle without its `manifestDigest` property. Object member ordering in
the checked-in document is therefore part of the v1 canonical representation.
