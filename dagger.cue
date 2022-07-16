package main

import (
    "dagger.io/dagger"
    "dagger.io/dagger/core"
    "universe.dagger.io/docker"
    "universe.dagger.io/docker/cli"
)

// This action builds a docker image from a python app.
// Build steps are defined in native CUE.
#CargoBuild: {
    // Source code of the Python application
    app: dagger.#FS

    // Resulting container image
    image: _build.output

    // Build steps
    _s1: docker.#Build & {
        steps: [
            docker.#Pull & {
                source: "rust:1.62-slim-bullseye"
            },
            docker.#Copy & {
                contents: app
                dest:     "/app"
            },
            docker.#Set & {
              config: workdir: "/app"
            },
            docker.#Run & {
              command: {
                name: "mkdir",
                args: ["/app/target"]
              }
            },
            docker.#Run & {
                command: {
                    name: "cargo"
                    args: ["build"]
                },
                mounts: {
                  buildCache: {
                    dest: "/app/target"
                    contents: core.#CacheDir & {
                       id: "app-cargo-cache"
                    }
                  }

                  regCache: {
                    dest: "/usr/local/cargo/registry"
                    contents: core.#CacheDir & {
                       id: "cargo-reg-cache"
                    }
                  }
                }
            },
        ]
    }


    _build: docker.#Build & {
      steps: [
        docker.#Pull & {
          source: "rust:1.62-slim-bullseye"
        },
        docker.#Copy & {
            contents: _s1.output.rootfs,
            source: "/app/target/debug/dagger-rust"
            dest:     "/app/dagger-rust"
        },
        docker.#Set & {
            config: cmd: ["/app/dagger-rust"]
        },
      ]
    }
}

// Example usage in a plan
dagger.#Plan & {
    client: filesystem: ".": read: contents: dagger.#FS,
    client: network: "unix:///var/run/docker.sock": connect: dagger.#Socket,

    actions: {
      build: #CargoBuild & {
        app: client.filesystem.".".read.contents
      },

      load: cli.#Load & {
          image: build._build.output
          host:  client.network."unix:///var/run/docker.sock".connect
          tag:   "app-image"
      }
    }
}