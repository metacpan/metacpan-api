# Use the latest 2.1 version of CircleCI pipeline process engine. See: https://circleci.com/docs/2.0/configuration-reference
version: 2.1
# Orchestrate or schedule a set of jobs
workflows:
  docker-compose:
    jobs:
      - build-and-test
jobs:
  build-and-test:
    machine: true
    resource_class: medium
    steps:
      # CircleCI has its own docker-compose already installed, but as of this writing, their version is too old to understand our docker-compose.yml
      - run:
          name: Install Docker Compose
          command: |
            set -x
            curl -L https://github.com/docker/compose/releases/download/1.26.2/docker-compose-`uname -s`-`uname -m` > /home/circleci/bin/docker-compose
            sudo chmod +x /home/circleci/bin/docker-compose
            which docker-compose
            docker-compose --version
      - run:
          command: |
            git clone https://github.com/metacpan/metacpan-docker.git
            cd metacpan-docker
          name: metacpan-docker checkout
      - run:
          command: |
            pushd metacpan-docker
            ./bin/metacpan-docker init
          name: clone missing repositories
      - run:
          command: |
            pushd metacpan-docker/src/metacpan-api
            git checkout ${CIRCLE_BRANCH}
          name: metacpan-api checkout
      - run:
          command: |
            pushd metacpan-docker
            docker-compose build --build-arg CPM_ARGS='--with-test' api_test
          name: compose build
      - run:
          command: |
            pushd metacpan-docker
            ./bin/metacpan-docker init
            docker-compose --verbose up -d api_test
          name: compose up
      # Since we're running docker-compose -d, we don't actually know if
      # Elasticsearch is available at the time this build step begins. We
      # probably need to wait for it here, so we'll add our own check.
      - run:
          command: |
            pushd metacpan-docker
            ./src/metacpan-api/wait-for-es.sh http://localhost:9200 elasticsearch_test --
          name: wait for ES
      - run:
          command: |
            pushd metacpan-docker
            docker-compose exec -T api_test prove -lr --jobs 2 t
      - run:
          command: |
            pushd metacpan-docker
            docker-compose logs
            docker stats --no-stream
            docker ps -a | head
          name: docker-compose logs
          when: on_fail
