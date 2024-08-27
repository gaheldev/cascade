import std.math;
import dplug.core;
import oscillator;
import solver;


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
                v.play(note,
				       velocity,
				       _pitchBend,
				       attack,
				       e0,
				       en,
				       nu,
				       k0,
				       lambda,
				       alpha,
				       beta,
				       a,
				       b,
				       eta,
				      ); // note: here pitch bend only applied at start of note, and not updated later.

		// TODO: round robin
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
	float attack = 0.005;
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
		foreach (osc; _osc)
			osc.waveForm = value;
    }

    WaveForm waveForm()
    {
        return _osc[0].waveForm;
    }

    void play(int note,
	          int velocity,
	          float bend,
		      float attack,
	          float e0,
	          float en,
	          float nu,
	          float k0,
	          float lambda,
	          float alpha,
	          float beta,
	          float a,
	          float b,
	          float eta,
	         ) @trusted
    {
        _noteOriginal = note;
		float fundamental = convertMIDINoteToFrequency(note + bend * 12);
		foreach (i; 0..int(_osc.length))
			_osc[i].frequency = fundamental * (i+1);

        _isPlaying = true;
        _volume = velocity / 128.0f;

		// TODO: handle attack

		initLevels(e0, en);
		_solver.nu = nu;
		_solver.k0 = k0;
		_solver.lambda = lambda;
		_solver.alpha = alpha;
		_solver.beta = beta;
		_solver.a = a;
		_solver.b = b;
		_solver.eta = eta;
    }

    void release()
    {
        _isPlaying = false;
    }

    void reset(float sampleRate)
    {
        release();
		initOsc(sampleRate);
		initLevels(1.0, 1.0);
		_solver.delta_t = 1.0/sampleRate;
    }

	void initOsc(float sampleRate)
	{
		foreach (osc; _osc)
			osc.sampleRate = sampleRate;
	}

	void initLevels(float e0, float en)
	{
		_solver.levels[0] = e0;
		_solver.levels[$-1] = en;
		foreach (n; 1..int(_solver.levels.length-1))
			_solver.levels[n] = _excitation;
	}

    float nextSample()
    {
        if (!_isPlaying)
            return 0;

		_solver.nextStep();

		float harmonicSample = 0.0;
		foreach (n; 1..int(_solver.levels.length-1))
			harmonicSample += _solver.levels[n] * _osc[n-1].nextSample();
        return harmonicSample * _volume;
    }


private:
    Oscillator[10] _osc;
    bool _isPlaying;
    int _noteOriginal = -1;
    float _volume = 1.0f;

	float _excitation = 1.0;
	Solver _solver = new Solver();
}
