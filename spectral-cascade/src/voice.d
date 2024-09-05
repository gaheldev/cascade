import dplug.core;
import std.math : abs;

import oscillator;
import solver;
import envelope;
import config;


struct Voice
{
nothrow @nogc:
public:

    bool isPlaying() { return _isPlaying; }

    void stop()
    {
        _solverIntp.initLevels(0.0, 0.0, 0.0);
        _attack.rearm();
        _release.rearm();
        _isPlaying = false;
        _isReleasingQuickly = false;
    }

    bool isReleasing()
    {
        return isPlaying && _release.isReleasing;
    }

    bool isReleasingQuickly()
    {
        return isReleasing && _isReleasingQuickly;
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

        _volume = status.velocity / 128.0f;

        _attackTime = status.attackTime;
        _releaseTime = status.releaseTime;

        _solverIntp.initLevels(status.e0, status.en, _excitation);
        _solverIntp.setParams(status);

        attack();
        _isPlaying = true;
    }

    void attack()
    {
        _attack.trigger(_attackTime);
    }

    void release()
    {
        _release.trigger(_releaseTime);
    }

    void quasiInstantRelease()
    {
        _release.trigger(0.005);
        _isReleasingQuickly = true;
    }

    bool closeToZeroCrossing(float value)
    {
        if (abs(value) < DENORMAL)
            return true;

        return false;
    }

    void instantRelease()
    {
        stop();
    }

    void reset(float sampleRate)
    {
        instantRelease();
        initOsc(sampleRate);
        _solverIntp.initLevels(0.0, 0.0, 0.0);
        _solverIntp.sampleRate = sampleRate;
        _attack.reset(sampleRate);
        _release.reset(sampleRate);
        _isReleasingQuickly = false;
    }

	void initOsc(float sampleRate)
	{
		foreach (ref osc; _osc)
			osc.sampleRate = sampleRate;
	}

    void prepareBuffer(int frames)
    {
        _solverIntp.prepareBuffer(frames);
    }

    float nextSample()
    {
        if (_release.isReleased)
            stop();

        if (!_solverIntp.isProcessing)
            stop();

        if (!isPlaying)
            return 0;

        _solverIntp.process();

        float harmonicSample = 0.0;
        foreach (n; 0..N_HARMONICS)
            harmonicSample += _solverIntp.level(n) * _osc[n].nextSample();
        harmonicSample *= _volume;
        harmonicSample *= _attack.process();
        harmonicSample *= _release.process();

        if (_isReleasingQuickly && closeToZeroCrossing(harmonicSample))
            stop();

        return harmonicSample;
    }


private:
    Oscillator[10] _osc;
    bool _isPlaying = false;
    bool _isReleasingQuickly = false;
    int _noteOriginal = -1;
    float _volume = 1.0f;
    float _excitation = 1.0f;

    SolverInterpolator _solverIntp;
    Attack _attack;
    Release _release;
    float _attackTime;
    float _releaseTime;
}


struct SolverInterpolator
{
nothrow @nogc:
public:

    @property float sampleRate() { return m_sampleRate; }
    @property float sampleRate(float value)
    {
        m_sampleRate = value;
        _solver.delta_t = 1.0f / sampleRate;
        return m_sampleRate;
    }

    bool isProcessing() { return _solver.isProcessing; }

	void initLevels(float e0, float en, float exciteAmount)
	{
        _solver.levels[0] = e0;
        _solver.levels[$-1] = en;
        _solver.excite(exciteAmount);
        _oldLevels = _solver.levels;
	}

    void setParams(VoiceStatus status)
    {
        _solver.nu = status.nu;
        _solver.k0 = status.k0;
        _solver.lambda = status.lambda;
        _solver.alpha = status.alpha;
        _solver.beta = status.beta;
        _solver.a = status.a;
        _solver.b = status.b;
        _solver.eta = status.eta;
    }

    float level(int n)
    {
        return _levels[n+1];
    }

    void prepareBuffer(int frames)
    {
        // get last buffer level
        _oldLevels = _solver.levels;

        // compute next level for last frame
        _solver.delta_t = frames / sampleRate;
        _solver.nextStep();
        _nextLevels = _solver.levels;

        _framesToInterpolate = frames;
        _step = 0;
    }

    void process()
    {
        _step += 1;
        _interpolate(_step);
    }


private:
    Solver _solver;
    float m_sampleRate = 48000;
    int _framesToInterpolate = 1;
    int _step = 0;

    float[N_HARMONICS+2] _levels;
    float[N_HARMONICS+2] _nextLevels;
    float[N_HARMONICS+2] _oldLevels;

    void _interpolate(int step)
    {
        float weight = step / _framesToInterpolate;
        foreach (i; 1..cast(int) (_levels.length - 1))
            _levels[i] = weight * _nextLevels[i] + (1 - weight) * _oldLevels[i];

    }
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

    
unittest
{
    // Test initialization and reset
    {
        Voice voice;
        voice.reset(48000);
        assert(!voice.isPlaying);
        assert(!voice.isReleasing);
        assert(voice.waveForm == WaveForm.saw); // Assuming default waveform is saw
    }

        
    VoiceStatus status;
    status.note = 60; // Middle C
    status.velocity = 100;
    status.pitchBend = 0;
    status.attackTime = 0.01;
    status.releaseTime = 0.1;
    status.e0 = 1.0;
    status.en = 1.0;
    status.nu = 1.0;
    status.k0 = 1.0;
    status.lambda = 1.5;
    status.alpha = 0.1;
    status.beta = 0.9;
    status.a = 1.0;
    status.b = 1.0;
    status.eta = 1.0;

    // Test play and isPlaying
    {
        Voice voice;
        voice.reset(48000);

        voice.play(status);
        assert(voice.isPlaying);
        assert(!voice.isReleasing);
        assert(voice.noteWithoutBend() == 60);
    }

    // Test release
    {
        Voice voice;
        voice.reset(48000);
        
        voice.play(status);

        voice.release();
        assert(voice.isPlaying);
        assert(voice.isReleasing);
    }

    // Test quasiInstantRelease
    {
        Voice voice;
        voice.reset(48000);
        
        voice.play(status);

        voice.quasiInstantRelease();
        assert(voice.isPlaying);
        assert(voice.isReleasing);

        // complete the instant release (a sample more than 0.001s)
        foreach (i; 0..50)
            voice.nextSample();
        assert(!voice.isPlaying);
        assert(!voice.isReleasing);
    }

    // Test instantRelease
    {
        Voice voice;
        voice.reset(48000);
        
        voice.play(status);

        voice.instantRelease();
        assert(!voice.isPlaying);
        assert(!voice.isReleasing);
    }

    // Test nextSample
    {
        Voice voice;
        voice.reset(48000);
        
        voice.play(status);

        float sample = voice.nextSample();
        assert(voice.isPlaying); 

        voice.instantRelease();
        sample = voice.nextSample();
        assert(sample == 0.0f); // Sample should be zero after release
    }

    // Test waveForm setter and getter
    {
        Voice voice;
        voice.reset(48000);

        voice.waveForm = WaveForm.square;
        assert(voice.waveForm == WaveForm.square);
    }
}
