Dagger rust example
===========

Whats in here:
  - Simple Rust program with some tests
  - [Dagger](https://dagger.io/) file with ci related actions:
    - build debug image
    - build production image
    - run tests
  - Github workflow that uses these actions
  - Cache efficient docker build
  - Cache layers using gha caching target 