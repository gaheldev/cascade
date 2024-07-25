synths := spectralSynth #chords


spectralSynth: dsp/*.dsp dsp/*.lib
	./build-plugin dsp/spectralSynth.dsp


# chords: dsp/*.dsp dsp/*.lib
# 	. build-plugin dsp/chords.dsp


vst3_dirs := $(foreach synth, $(synths), plugins/juce/$(synth)/Builds/LinuxMakefile/build/$(synth).vst3)
install:
	for vst3 in $(vst3_dirs) ; do cp -r $$vst3 ~/.vst3/; done 
