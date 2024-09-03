import std.math;
import dplug.core;

import oscillator;
import roundrobin;
import envelope;
import solver;
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
        // note: here pitch bend only applied at start of note,
        // and not updated later.
        // TODO: remove and fix handleVoiceQueue()
        int next = _roundRobin.next();
        _roundRobin.markBusy(next);
        /* auto v = _voices[next]; */
        /* if (v.isPlaying) */
        /*     _voiceQueue.push(status); */
        /* _voices[_roundRobin.next()].play(status); */
        _voices[next].play(_voiceQueue.pop());
    }

    void markNoteOff(int note)
    {
        // let the solver control the release
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
                v.instantRelease();
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
            if (!_voices[i].isPlaying)
                _roundRobin.markFree(i);
    }

    void handleVoiceQueue()
    {
        // TODO: isFull?
        if (_voiceQueue.empty)
            return;

        int nextVoice = _roundRobin.next();
        auto v = _voices[nextVoice];
        if (v.isPlaying)
        {
            _roundRobin.markFreeing(nextVoice);
            v.quasiInstantRelease();
        }
        else
        {
            _roundRobin.markBusy(nextVoice);
            v.play(_voiceQueue.pop());
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
	float releaseTime = 0.005;
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


struct Voice
{
nothrow @nogc:
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
		foreach (ref osc; _osc)
			osc.waveForm = value;
    }

    WaveForm waveForm()
    {
        return _osc[0].waveForm;
    }

    void play(VoiceStatus status) @trusted
    {
        _noteOriginal = status.note;
        float fundamental = convertMIDINoteToFrequency(status.note + status.pitchBend * 12);
        foreach (i; 0..N_HARMONICS)
            _osc[i].frequency = fundamental * (i+1);

        _isPlaying = true;
        _volume = status.velocity / 128.0f;

        _attack.trigger(status.attackTime);

        initLevels(status.e0, status.en, _excitation);
        _solver.nu = status.nu;
        _solver.k0 = status.k0;
        _solver.lambda = status.lambda;
        _solver.alpha = status.alpha;
        _solver.beta = status.beta;
        _solver.a = status.a;
        _solver.b = status.b;
        _solver.eta = status.eta;
    }

    void release()
    {
        _release.trigger();
        _isReleasing = true;
    }

    void quasiInstantRelease()
    {
        _release.trigger(0.001);
        _isReleasing = true;
    }

    void instantRelease()
    {
        _isPlaying = false;
    }

    void reset(float sampleRate)
    {
        release();
		initOsc(sampleRate);
		initLevels(0.0, 0.0, 0.0);
		_solver.delta_t = 1.0/sampleRate;
        _attack.reset(sampleRate);
    }

	void initOsc(float sampleRate)
	{
		foreach (ref osc; _osc)
			osc.sampleRate = sampleRate;
	}

	void initLevels(float e0, float en, float exciteAmount)
	{
        _solver.levels[0] = e0;
        _solver.levels[$-1] = en;
        _solver.excite(exciteAmount);
	}

    float nextSample()
    {
        if (_isReleasing && !_release.isReleasing)
        {
            _isReleasing = false;
            _isPlaying = false;
        }

        if (!_isPlaying)
            return 0;

        _solver.nextStep();

        float harmonicSample = 0.0;
        foreach (n; 0..N_HARMONICS)
            harmonicSample += _solver.levels[n+1] * _osc[n].nextSample();
        return harmonicSample * _volume * _attack.process();
    }


private:
    Oscillator[10] _osc;
    bool _isPlaying;
    bool _isReleasing;
    int _noteOriginal = -1;
    float _volume = 1.0f;

    float _excitation = 1.0f;
    Solver _solver;
    Attack _attack;
    Release _release;
}

struct VoiceStatus
{
    int note;
	int velocity;
	float pitchBend;
	float attackTime;
	float releaseTime;
	float e0;
	float en;
	float nu;
	float k0;
	float lambda;
	float alpha;
	float beta;
	float a;
	float b;
	float eta;
}
