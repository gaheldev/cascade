import std.math;
import std.algorithm : min;
import dplug.core;

import oscillator;
import voice;
import queues;
import envelope;
import config;


struct Synth(size_t voicesCount)
{
nothrow @nogc:
public:

    static assert(voicesCount > 0, "A synth must have at least 1 voice.");

    bool isPlaying = false;

    bool anyVoicePlaying()
    {
        foreach (v; _voices)
            if (v.isPlaying)
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
        if (panic) return;

        isPlaying = true;

        VoiceStatus status;
        status.note = note;
        status.velocity = velocity;
        status.pitchBend = _pitchBend;
        status.attackTime = attackTime;
        status.releaseTime = releaseTime;
        status.interpolate = interpolate;
        status.e0 = e0;
        status.en = en;
        status.excitation = excitation;
        status.nu = nu;
        status.k0 = k0;
        status.lambda = lambda;
        status.alpha = alpha;
        status.beta = beta;
        status.a = a;
        status.b = b;
        status.eta = eta;

        _voiceQueue.push(status);
    }

    void markNoteOff(int note)
    {
        foreach (int i; 0.._voices.length)
        {
            auto v = &_voices[i];
            if (v.isPlaying && v.noteWithoutBend == note)
                releaseVoice(i);
        }
    }

    void markAllNotesOff()
    {
        foreach (int i; 0.._voices.length)
            if (_voices[i].isPlaying)
                quasiInstantReleaseVoice(i);
    }

    @property bool panic() { return _panic; }
    @property bool panic(bool value)
    {
        if (value)
        {
            foreach (ref v; _voices)
                v.instantRelease();

            _voiceQueue.empty();
            _roundRobin.reset();
        }

        return _panic = value;
    }

    @property int activeVoices() { return _activeVoices; }
    @property int activeVoices(int value)
    {
        if (value < _activeVoices)
        {
            // reset higher voices
            foreach (i; value..cast(int) _voices.length)
            {
                _voices[i].instantRelease();
            }
        }

        if (value != _activeVoices)
        {
            _voiceQueue.empty();
            _roundRobin.reset();
            _roundRobin.maxElt = value;
        }
        return _activeVoices = value;
    }

    void reset(float sampleRate)
    {
        foreach (ref v; _voices)
            v.reset(sampleRate);

        _voiceQueue.empty();
        _roundRobin.reset();
    }

    void playNextQueuedVoice(int i)
    {
            _voices[i].play(_voiceQueue.pop());
            _roundRobin.markBusy(i);
    }

    void releaseVoice(int i)
    {
            _voices[i].release();
            _roundRobin.markSlowlyFreeing(i);
    }

    void quasiInstantReleaseVoice(int i)
    {
            _voices[i].quasiInstantRelease();
            _roundRobin.markFreeing(i);
    }

    void freeReleasedVoices()
    {
        foreach (i; 0.._activeVoices)
        {
            if (!_voices[i].isPlaying)
                _roundRobin.markFree(i);
        }
    }

    void handleVoiceQueue()
    {
        // TODO: isFull?
        if (_voiceQueue.isEmpty)
            return;

        auto scheduledVoices = _roundRobin.scheduled;
        int n = min(_voiceQueue.length, _activeVoices);
        foreach (i; 0..n)
        {
            int scheduled = scheduledVoices[i];
            auto v = &_voices[scheduled];

            if (v.isPlaying && !v.isReleasingQuickly)
                quasiInstantReleaseVoice(scheduled);

            if (v.isPlaying && v.isReleasingQuickly)
            {
                // wait for this voice or another one
                // to be fully released
            }

            // note: here pitch bend only applied at start of note,
            // and not updated later.
            if (!v.isPlaying)
                playNextQueuedVoice(scheduled);
        }
    }

    void prepareBuffer(int frames)
    {
        foreach (ref v; _voices)
            v.prepareBuffer(frames);
    }

    float nextSample()
    {
        if (panic) return 0;

        freeReleasedVoices();
        handleVoiceQueue();

        if (!anyVoicePlaying())
            isPlaying = false;

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
    float attackTime = 0.01;
    float releaseTime = 1;
    bool interpolate = true;
    float e0 = 1.0;
    float en = 1.0;
    float excitation = 1.0;
    float nu = 1.0;
    float k0 = 1.0;
    float lambda = 1.5;
    float alpha = 0.1;
    float beta = 0.9;
    float a = 1.0;
    float b = 1.0;
    float eta = 1.0;

private:
    enum double _internalGain = (1.0 / (voicesCount / SQRT1_2));
    RoundRobin!voicesCount _roundRobin;
    bool _panic = false;
    int _activeVoices;

    float _pitchBend = 0.0f; // -1 to 1, change one semitone

    Voice[voicesCount] _voices;
    Queue!(VoiceStatus, 10) _voiceQueue; // 10 notes at most in queue should be ok
}

