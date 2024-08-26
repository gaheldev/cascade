all: build deploy

build:
	dplug-build -c VST3

deploy: build
	cp -r builds/Linux-64b-VST3/Gahel\ Spectral\ Cascade.vst3/ ~/.vst3/
	# cp -r builds/Linux-64b-LV2/Gahel\ Spectral\ Cascade.lv2/ ~/.lv2/
