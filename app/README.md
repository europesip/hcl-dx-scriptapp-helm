# Hello DX (Script Application)

The sample app of this repository: see the [main README](../README.md) for what it does, how the
Helm chart deploys it and how to develop it locally.

- [src/App.tsx](src/App.tsx): the page.
- [src/dx.ts](src/dx.ts): the calls to DX, as the signed-in user (same origin, no secrets).
- [Dockerfile](Dockerfile): the bundle image the chart pushes.
- [deploy.cjs](deploy.cjs): HCL's script for `npm run dx-deploy` from a workstation.
