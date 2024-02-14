variable "IMAGE_FLAVOR" { default = "asus" }
variable "AKMODS_FLAVOR" { default = "asus" }
variable "FEDORA_MAJOR_VERSION" { default = "39" }
variable "IMAGE_NAME" { default = "orora-bluefin" }

group "default" {
  targets = ["orora-bluefin"]
}

target orora-meta {
  labels = {
    "org.opencontainers.image.authors" = "Hikaru"
    "org.opencontainers.image.title" = "Orora Bluefin"
    "org.opencontainers.image.description" = "An interpretation of the Ubuntu spirit built on Fedora technology"
    "io.artifacthub.package.readme-url" = "https://raw.githubusercontent.com/bayou-brogrammer/bluefin/main/README.md"
    "io.artifacthub.package.logo-url" = "https://raw.githubusercontent.com/bayou-brogrammer/bluefin/main/assets/4-design/variant5.png"
  }

  annotations = [
    "org.opencontainers.image.authors=Hikaru",
    "org.opencontainers.image.title=Orora Bluefin",
    "org.opencontainers.image.description=An interpretation of the Ubuntu spirit built on Fedora technology"
  ]
}

target "docker-metadata-action" {
  cache-from = ["type=gha"]
  cache-to = ["type=gha,mode=max"]
}

target "orora-bluefin" {
  context = "./"
  dockerfile = "Dockerfile"

  args {
    BUILDX_EXPERIMENTAL = 1
    IMAGE_NAME = "${IMAGE_NAME}"
    IMAGE_FLAVOR = "${IMAGE_FLAVOR}"
    AKMODS_FLAVOR = "${AKMODS_FLAVOR}"
    FEDORA_MAJOR_VERSION = "${FEDORA_MAJOR_VERSION}"
  }

  inherits = ["docker-metadata-action", "orora-meta"]
}
