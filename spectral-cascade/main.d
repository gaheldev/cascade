/**
Aliased polyphonic syntesizer.

Copyright: Elias Batek 2018, 2021.
License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
*/
import std.math;
import dplug.core, dplug.client;

import synth;
import oscillator;
import config;


// This define entry points for plugin formats, 
// depending on which version identifiers are defined.
mixin(pluginEntryPoints!SpectralCascade);

enum : int
{
    paramOsc1WaveForm,
    paramOutputGain,
	paramAttack,
	paramE0,
	paramEn,
	paramNu,
	paramK0,
	paramLambda,
	paramAlpha,
	paramBeta,
	paramA,
	paramB,
	paramEta,
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

        params ~= mallocNew!LinearFloatParameter(paramAttack, "Attack", "s", 0.0, 0.2, 0.005);
        params ~= mallocNew!LinearFloatParameter(paramE0, "E0", "", 0.0, 1.0, 1.0);
        params ~= mallocNew!LinearFloatParameter(paramEn, "En", "", 0.0, 1.0, 1.0);
        params ~= mallocNew!LinearFloatParameter(paramNu, "nu", "", 0.0, 1.0, 1.0);
        params ~= mallocNew!LinearFloatParameter(paramK0, "k0", "", 0.0, 10.0, 1.0);
        params ~= mallocNew!LinearFloatParameter(paramLambda, "lambda", "", 1.0 + float.min_normal, 3.0, 1.5);
        params ~= mallocNew!LinearFloatParameter(paramAlpha, "alpha", "", float.min_normal, 0.5-float.min_normal, 0.1);
        params ~= mallocNew!LinearFloatParameter(paramBeta, "beta", "", 0.5+float.min_normal, 10.0, 0.9);
        params ~= mallocNew!LinearFloatParameter(paramA, "a,", "", 0.0, 10.0, 1.0);
        params ~= mallocNew!LinearFloatParameter(paramB, "b,", "", float.min_normal, 10.0, 1.0);
        params ~= mallocNew!LinearFloatParameter(paramEta, "eta", "", 0.0, 2.0, 1.0);

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
        _synth.waveForm = readParam!WaveForm(paramOsc1WaveForm);
        _synth.outputGain = convertDecibelToLinearGain(readParam!float(paramOutputGain));
        _synth.attack = readParam!float(paramAttack);
        _synth.e0 = readParam!float(paramE0);
        _synth.en = readParam!float(paramEn);
        _synth.nu = readParam!float(paramNu);
        _synth.k0 = readParam!float(paramK0);
        _synth.lambda = readParam!float(paramLambda);
        _synth.alpha = readParam!float(paramAlpha);
        _synth.beta = readParam!float(paramBeta);
        _synth.a = readParam!float(paramA);
        _synth.b = readParam!float(paramB);
        _synth.eta = readParam!float(paramEta);

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

        foreach (ref sample; outputs[0][0 .. frames])
            sample = _synth.nextSample();

        // Copy output to every channel
        foreach (chan; 1 .. outputs.length)
            outputs[chan][0 .. frames] = outputs[0][0 .. frames];
    }

private:
    Synth!maxVoices _synth;
}

