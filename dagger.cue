package main

import (
    "dagger.io/dagger"
    "universe.dagger.io/docker"
    "universe.dagger.io/docker/cli"
)

#CargoBuild: {
    app: dagger.#FS

    release: bool | *false

    // Resulting container image
    image: _prodStage.output

    // Build app using rust image and cargo build
    _buildStage: docker.#Build & {
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
                  name: "cargo",
                  args: ["build", if release {"--release"}]
                  
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
                  args: ["build", if release {"--release"}]
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
            docker.#Set & {
              config: cmd: ["/app/dagger-rust"]
            },
        ]
    }

    _prodStage: docker.#Build & {
      steps: [
        docker.#Pull & {
          source: "debian:buster-slim"
        },
        docker.#Copy & {
            contents: _buildStage.output.rootfs,
            source: "/app/target/debug/dagger-rust"
            dest:     "/app/dagger-rust"
        },
        docker.#Set & {
            config: cmd: ["/app/dagger-rust"]
        },
      ]
    }
}

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

      buildProd: #CargoBuild & {
        app: client.filesystem.".".read.contents
        release: true
      },

      load: cli.#Load & {
          image: build.image
          host:  client.network."unix:///var/run/docker.sock".connect
          tag:   "dagger-rust"
      },

      test: docker.#Run & {
        input: build._buildStage.output,
        command: {
          name: "cargo",
          args: ["test"]
        }
      }
    }
}