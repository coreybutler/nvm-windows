# Contributing

## Developer Certificate of Origin (DCO)

All contributions must include a `Signed-off-by` trailer on every commit. This certifies that you have the right to submit the work under the project's MIT license and that it may be used in both community and certified builds.

Use `git commit -s` (or `git commit --amend -s`) to add the trailer automatically. Example:

```
Signed-off-by: Your Name <your.email@example.com>
```

The email should match the one associated with your GitHub account. The DCO check is a required status check; pull requests missing it cannot be merged.

For more background see [Developer Certificate of Origin](https://developercertificate.org/).

## Pull requests

Fill in `.github/pull_request_template.md`:

- **What** changed
- **Why** it exists
- **Testing** you ran
- **Risk** (what could break)

Dependency review runs on lockfile and manifest changes. It fails when a pull request introduces a known-vulnerable package.
