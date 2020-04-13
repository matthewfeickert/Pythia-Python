default: image

all: image

image:
	docker build . \
	-f Dockerfile \
	--build-arg BASE_IMAGE=python:3.7-slim \
	--build-arg HEPMC_VERSION=3.2.1 \
	--build-arg FASTJET_VERSION=3.3.3 \
	--build-arg PYTHIA_VERSION=8301 \
	--tag matthewfeickert/pythia-python:pythia8.301 \
	--tag matthewfeickert/pythia-python:pythia8.301-hepmc3.2.1-fastjet3.3.3-python3.7 \
	--tag matthewfeickert/pythia-python:latest

run:
	docker run --rm -it matthewfeickert/pythia-python:latest

test:
	docker run \
		--rm \
		-v $(shell pwd):$(shell pwd) \
		-w $(shell pwd) \
		matthewfeickert/pythia-python:latest \
		"g++ tests/main01.cc -o tests/main01 -lpythia8 -ldl; ./tests/main01 > main01_out_cpp.txt"
	wc main01_out_cpp.txt
	docker run \
		--rm \
		-v $(shell pwd):$(shell pwd) \
		-w $(shell pwd) \
		matthewfeickert/pythia-python:latest \
		"python tests/main01.py > main01_out_py.txt"
	wc main01_out_py.txt
