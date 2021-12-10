[![Test](https://github.com/cloudfoundry/go-cf-api-release/actions/workflows/rspec.yml/badge.svg)](https://github.com/cloudfoundry/go-cf-api-release/actions/workflows/rspec.yml) [![Lint](https://github.com/cloudfoundry/go-cf-api-release/actions/workflows/rubocop.yml/badge.svg)](https://github.com/cloudfoundry/go-cf-api-release/actions/workflows/rubocop.yml)

# GO-CF-API BOSH Release
BOSH release for Golang PoC implementation of the Cloud Controller


## Project setup
After cloning make sure you got the submodules checked out as well `git submodule update --init --recursive`

You need to install the [bosh cli](https://bosh.io/docs/cli-v2-install/)

Install the ruby version according to the [.ruby-version](.ruby-version) file

After installing ruby run `bundle install`

## Running spec tests
Templates should always include `rspec` tests to ensure the templating works as intended.
See the [spec/](spec) directory for existing tests and examples.
To run the tests:
```bash
bundle exec rspec -P spec/*_spec.rb
```

## Building a final release tarball
Final releases are not built automatically at the moment.

To create a new tag do the following:
```
# Get the latest tag
git fetch --tags
git describe --tags --abbrev=0

# Using the next version after the latest tag
git tag "v<next_version>"
git push
git push --tags
```
## Building a release locally
We do not currently have a shared/public blobstore.
This means that you will not be able to pull/push blobs for previous releases or use the vendored golang package.
To create a new dev release:
```
bosh vendor-package golang-1.17-linux ./src/golang-release
bosh create-release --tarball "go-cf-api-release.tgz"
```
