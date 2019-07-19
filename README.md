# The repo contains Packer that build an GCP Image with Consul server - the Image is "ubuntu-1804-lts" based with latest updates.
### This will build an GCP Image with [Consul](https://www.consul.io/) server installed . 

## Usage example:


- Setup your [gcloud command-line tool](https://cloud.google.com/sdk/)

- If you need the latest version of Consul - from your CLI execute a following command:

```
packer build servers.json
``` 
If you need specific version 
```
packer build -var 'CONSUL=1.4.2' servers.json
``` 

For more info please check a following link:

https://www.packer.io/intro/getting-started/build-image.html#some-more-examples-

To test you will need Kitchen:

Kitchen is a RubyGem so please find how to install and setup Test Kitchen for developing infrastructure code, check out the [Getting Started Guide](http://kitchen.ci/docs/getting-started/).

A following [gems](https://guides.rubygems.org/what-is-a-gem/) should be installed:

```
bundle install
```
Than simply execute a following commands:

```
bundle kitchen converge
bundle kitchen verify
bundle kitchen destroy
```
The result should be as follow
``` 
  ✔  operating_system: Command: `lsb_release -a`
     ✔  Command: `lsb_release -a` stdout should match /Ubuntu/

  File /usr/local/bin/consul
     ✔  should exist
  File /etc/systemd/system/consul.service
     ✔  should exist
  File /etc/consul.d/server.json
     ✔  should exist

Profile Summary: 1 successful control, 0 control failures, 0 controls skipped
Test Summary: 4 successful, 0 failures, 0 skipped
       Finished verifying <default-ubuntu> (0m7.18s)
```
