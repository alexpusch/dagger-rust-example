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
            docker.#Run & {
              command: {
                name: "cargo",
                args: ["new", "/app"]
              }
            },
            docker.#Set & {
              config: workdir: "/app"
            },
            docker.#Copy & {
              contents: app
              include: ["Cargo.toml", "Cargo.lock"]
              dest:     "/app"
            },
            docker.#Run & {
              command: {
                  name: "cargo"
                  args: ["build"]
              },
              // mounts: {
              //   buildCache: {
              //     dest: "/app/target"
              //     contents: core.#CacheDir & {
              //         id: "app-cargo-cache-build"
              //     }
              //   },

              //   regCache: {
              //     dest: "/usr/local/cargo/registry"
              //     contents: core.#CacheDir & {
              //         id: "cargo-reg-cache"
              //     }
              //   }
              // }
            },
            docker.#Copy & {
              contents: app
              dest:     "/app"
            },
            docker.#Run & {
              command: {
                  name: "cargo"
                  args: ["build"]
              },
              // mounts: {
              //   buildCache: {
              //     dest: "/app/target"
              //     contents: core.#CacheDir & {
              //         id: "app-cargo-cache-build"
              //     }
              //   },

              //   regCache: {
              //     dest: "/usr/local/cargo/registry"
              //     contents: core.#CacheDir & {
              //         id: "cargo-reg-cache"
              //     }
              //   }
              // }
            },
            docker.#Run & {
                command: {
                    name: "cp"
                    args: ["/app/target/debug/dagger-rust", "/app/dagger-rust"]
                },
                // mounts: {
                //   buildCache: {
                //     dest: "/app/target"
                //     contents: core.#CacheDir & {
                //        id: "app-cargo-cache-build"
                //     }
                //   },
                // }
            },
            docker.#Set & {
              config: cmd: ["/app/dagger-rust"]
            },
        ]
    }

    _build: docker.#Build & {
      steps: [
        docker.#Pull & {
          source: "debian:buster-slim"
        },
        docker.#Copy & {
            contents: _s1.output.rootfs,
            source: "/app/dagger-rust"
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
    client: filesystem: ".": read: {
      contents: dagger.#FS
      exclude: ["target", ".git"]

    },
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