# Tests in here are for development only

# Setup port forwarding to our staging server
ssh -L 9200:localhost:9200 leo@bm-mc-02.metacpan.org

# Run tests - with ES env
bin/prove_live xt/...
