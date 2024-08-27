import std.math;
import dplug.core;
import oscillator;


struct Synth(size_t voicesCount)
{
@safe pure nothrow @nogc:
public:

    static assert(voicesCount > 0, "A synth must have at least 1 voice.");

    bool isPlaying()
    {
        foreach (v; _voices)
            if (v.isPlaying())
                return true;

        return false;
    }

    WaveForm waveForm()
    {
        return _voices[0].waveForm;
    }

    void waveForm(WaveForm value)
    {
        foreach (ref v; _voices)
            v.waveForm = value;
    }

    void markNoteOn(int note, int velocity)
    {
        foreach (ref v; _voices)
            if (!v.isPlaying)
                return v.play(note, velocity, _pitchBend); // note: here pitch bend only applied at start of note, and not updated later.

        // no free voice available, skip
    }

    void markNoteOff(int note)
    {
        foreach (ref v; _voices)
            if (v.isPlaying && (v.noteWithoutBend == note))
                v.release();
    }

    void markAllNotesOff()
    {
        foreach (ref v; _voices)
            if (v.isPlaying)
                v.release();
    }

    void reset(float sampleRate)
    {
        foreach (ref v; _voices)
            v.reset(sampleRate);
    }

    float nextSample()
    {
        double sample = 0;

        foreach (ref v; _voices)
            sample += v.nextSample(); // synth

        // lower volume relative to the total count of voices
        sample *= _internalGain;

        // apply gain
        sample *= outputGain;

        return float(sample);
    }

    void setPitchBend(float bend)
    {
        _pitchBend = bend;
    }

    float outputGain = 1;

private:
    enum double _internalGain = (1.0 / (voicesCount / SQRT1_2));

    float _pitchBend = 0.0f; // -1 to 1, change one semitone

    VoiceStatus[voicesCount] _voices;
}

struct VoiceStatus
{
@safe pure nothrow @nogc:
public:

    bool isPlaying()
    {
        return _isPlaying;
    }

    int noteWithoutBend()
    {
        return _noteOriginal;
    }

    void waveForm(WaveForm value)
    {
        _osc.waveForm = value;
    }

    WaveForm waveForm()
    {
        return _osc.waveForm;
    }

    void play(int note, int velocity, float bend) @trusted
    {
        _noteOriginal = note;
        _osc.frequency = convertMIDINoteToFrequency(note + bend * 12);
        _isPlaying = true;
        _volume = velocity / 128.0f;
    }

    void release()
    {
        _isPlaying = false;
    }

    void reset(float sampleRate)
    {
        release();
        _osc.sampleRate = sampleRate;
    }

    float nextSample()
    {
        if (!_isPlaying)
            return 0;

        return _osc.nextSample() * _volume;
    }

private:
    Oscillator _osc;
    bool _isPlaying;
    int _noteOriginal = -1;
    float _volume = 1.0f;
}
