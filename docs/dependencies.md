# Carton

We use Carton to manage and pin our dependencies.  To run carton on the VM, you
have two options:

    vagrant provision

This will run a `carton install` along with any other general bootstrapping
which is required, but it can be a bit slow.

If you ssh to your vagrant box, this is faster:

    sh /home/vagrant/bin/metacpan-api-carton install
