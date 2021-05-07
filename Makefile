
build/with: with
	if [ ! -d build ]; then mkdir build; fi
	raco exe --orig-exe -o build/with with

clean:
	rm -rf build

