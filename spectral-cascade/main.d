/**
Aliased polyphonic syntesizer.

Copyright: Elias Batek 2018, 2021.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
import std.math;
import dplug.core, dplug.client;

import synth;
import oscillator;


// This define entry points for plugin formats, 
// depending on which version identifiers are defined.
mixin(pluginEntryPoints!SpectralCascade);

/// Number of max notes playing at the same time
enum maxVoices = 6;

enum : int
{
    paramOsc1WaveForm,
    paramOutputGain,
}

static immutable waveFormNames = [__traits(allMembers, WaveForm)];


/// Polyphonic digital-aliasing synth
final class SpectralCascade : Client
{
nothrow:
@nogc:
public:

    this()
    {
    }

    override PluginInfo buildPluginInfo()
    {
        // Plugin info is parsed from plugin.json here at compile time.
        // Indeed it is strongly recommended that you do not fill PluginInfo
        // manually, else the information could diverge.
        static immutable PluginInfo pluginInfo = parsePluginInfo(import("plugin.json"));
        return pluginInfo;
    }

    override Parameter[] buildParameters()
    {
        auto params = makeVec!Parameter();
        params ~= mallocNew!EnumParameter(paramOsc1WaveForm, "Waveform", waveFormNames, WaveForm.init);
        params ~= mallocNew!GainParameter(paramOutputGain, "Output Gain", 6.0, 0.0);
        return params.releaseData();
    }

    override LegalIO[] buildLegalIO()
    {
        auto io = makeVec!LegalIO();
        io ~= LegalIO(0, 1);
        io ~= LegalIO(0, 2);
        return io.releaseData();
    }

    override int maxFramesInProcess()
    {
        return 32; // samples only processed by a maximum of 32 samples
    }

    override void reset(double sampleRate, int maxFrames, int numInputs, int numOutputs)
    {
        _synth.reset(sampleRate);
    }

    override void processAudio(const(float*)[] inputs, float*[] outputs, int frames, TimeInfo info)
    {
        // process MIDI - note on/off and similar
        foreach (msg; getNextMidiMessages(frames))
        {
            if (msg.isNoteOn()) // note on
                _synth.markNoteOn(msg.noteNumber(), msg.noteVelocity());

            else if (msg.isNoteOff()) // note off
                _synth.markNoteOff(msg.noteNumber());

            else if (msg.isAllNotesOff() || msg.isAllSoundsOff()) // all off
                _synth.markAllNotesOff();

            else if (msg.isPitchBend())
                _synth.setPitchBend(msg.pitchBend());
        }

        _synth.waveForm = readParam!WaveForm(paramOsc1WaveForm);
        _synth.outputGain = convertDecibelToLinearGain(readParam!float(paramOutputGain));

        foreach (ref sample; outputs[0][0 .. frames])
            sample = _synth.nextSample();

        // Copy output to every channel
        foreach (chan; 1 .. outputs.length)
            outputs[chan][0 .. frames] = outputs[0][0 .. frames];
    }

private:
    Synth!maxVoices _synth;
}

