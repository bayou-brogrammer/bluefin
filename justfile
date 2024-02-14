set shell := ["bash", "-uc"]

default:
  just --list

bake *FLAGS:
	depot bake -f docker-bake.hcl {{FLAGS}}
bake-load:
	just bake --load
bake-no-cache:
	just bake --no-cache

build *FLAGS:
	depot build -f Dockerfile {{FLAGS}}
build-load:
	just build --load
build-no-cache:
	just build --no-cache
