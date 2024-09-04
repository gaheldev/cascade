import std.math;
import dplug.core;

import oscillator;
import voice;
import roundrobin;
import envelope;
import config;


struct Synth(size_t voicesCount)
{
nothrow @nogc:
public:

    static assert(voicesCount > 0, "A synth must have at least 1 voice.");

    bool isPlaying()
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

        VoiceStatus status;
        status.note = note;
        status.velocity = velocity;
        status.pitchBend = _pitchBend;
        status.attackTime = attackTime;
        status.releaseTime = releaseTime;
        status.e0 = e0;
        status.en = en;
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
        // let the solver control the release
        /* foreach (ref v; _voices) */
        /*     if (v.isPlaying && v.noteWithoutBend == note) */
        /*         v.release(); */
    }

    void markAllNotesOff()
    {
        foreach (ref v; _voices)
            if (v.isPlaying)
                v.quasiInstantRelease();
    }

    @property bool panic() { return _panic; }
    @property bool panic(bool value)
    {
        if (value)
            foreach (ref v; _voices)
            {
                // TODO: use v.quasiInstantRelease();
                v.instantRelease();
                _voiceQueue.empty();
                _roundRobin.reset();
            }

        return _panic = value;
    }

    void reset(float sampleRate)
    {
        foreach (ref v; _voices)
            v.reset(sampleRate);
    }

    void updateRoundRobin()
    {
        foreach (i; 0..cast(int)_voices.length)
        {
            if (!_voices[i].isPlaying)
                _roundRobin.markFree(i);
            else if (_voices[i].isReleasing)
                _roundRobin.markFreeing(i);
        }
    }

    void handleVoiceQueue()
    {
        // TODO: isFull?
        if (_voiceQueue.isEmpty)
            return;

        // TODO: handle multiple notes at once
        //       for that next(3) should return the 3 next
        auto nextVoice = _roundRobin.next;
        auto v = &_voices[nextVoice];
        if (v.isPlaying && !v.isReleasing)
        {
            v.quasiInstantRelease();
            _roundRobin.markFreeing(nextVoice);
        }

        if (v.isPlaying && v.isReleasing)
        {
            // wait for this voice or another one
            // to be fully released
        }

        if (!v.isPlaying)
        {
            // note: here pitch bend only applied at start of note,
            // and not updated later.
            v.play(_voiceQueue.pop());
            _roundRobin.markBusy(nextVoice);
        }
    }

    float nextSample()
    {
        if (panic) return 0;

        updateRoundRobin();
        handleVoiceQueue();

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
	float attackTime = 0.005;
	float releaseTime = 1;
	float e0 = 1.0;
	float en = 1.0;
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

    float _pitchBend = 0.0f; // -1 to 1, change one semitone

    Voice[voicesCount] _voices;
    Queue!(VoiceStatus, 10) _voiceQueue; // 10 notes at most in queue should be ok
}

