# Cloud Controller BOSH Release
BOSH release for Go implementation of the Cloud Controller

## Building a final release
We do not currently have a shared/public blobstore.
This means that you will not be able to pull/push blobs for previous releases or use the vendored golang package.
To create a new final release:
```
git clone git@github.com:bosh-packages/golang-release.git ~/work/golang-release
bosh vendor-package golang-1.16-linux ~/work/golang-release
# Get the latest tag
git fetch --tags
git describe --tags --abbrev=0
# Using the next version after the latest tag without the 'v'
export VERSION=<version>
bosh create-release --final --version "$VERSION" --tarball "cloudgontroller-boshrelease-$VERSION.tgz"
git tag "v$VERSION"
git push
git push --tags
```

This will leave you with a tarball named `cloudgontroller-boshrelease-0.0.X.tgz` which should be uploaded to Artifactory under the path `com/sap/cp/cloudfoundry/cloudgontroller-boshrelease/0.0.X`.
Get the Artifactory password from PassVault and run:
```
curl -f -u "deploy.releases.cfp:<artifactory_password>" --upload-file "cloudgontroller-boshrelease-$VERSION.tgz" "https://common.repositories.cloud.sap/artifactory/deploy.releases.sapcp/com/sap/cp/cloudfoundry/cloudgontroller-boshrelease/$VERSION/cloudgontroller-boshrelease-$VERSION.tgz"
```