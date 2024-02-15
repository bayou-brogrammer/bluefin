TAG := "orora-bluefin:latest"
set shell := ["bash", "-uc"]

default:
  just --list

build *FLAGS:
  buildah bud {{FLAGS}} --layers
build-load:
	just build --load
build-no-cache:
	just build --no-cache

build-dev *FLAGS:
	just build {{FLAGS}} -t orora-bluefin:dev 
build-dev-load:
	just build --load
build-dev-no-cache:
	just build --no-cache