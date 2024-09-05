import std.math;
// override some math functions
import dplug.core.math : sin = fast_sin;


enum double TAU = 2 * PI;

enum WaveForm
{
    saw,
    sine,
    square,
}


struct Oscillator
{
@safe pure nothrow @nogc:
public:

    this(WaveForm waveForm)
    {
        _waveForm = waveForm;
        recalculateDeltaPhase();
    }

    void frequency(float value)
    {
        _frequency = value;
        recalculateDeltaPhase();
    }

    void sampleRate(float value)
    {
        _sampleRate = value;
        recalculateDeltaPhase();
    }

    WaveForm waveForm()
    {
        return _waveForm;
    }

    void waveForm(WaveForm value)
    {
        _waveForm = value;
    }

    double nextSample()
    {
        double sample = void;

        final switch (_waveForm) with (WaveForm)
        {
        case saw:
            sample = 1.0 - (_phase / PI);
            break;

        case sine:
            sample = sin(_phase);
            break;

        case square:
            sample = (_phase <= PI) ? 1.0 : -1.0;
            break;
        }

        _phase += _deltaPhase;

        while (_phase >= TAU)
        {
            _phase -= TAU;
        }

        return sample;
    }

private:
    double _deltaPhase;
    float _frequency;
    double _phase = 0;
    float _sampleRate;
    WaveForm _waveForm;

    void recalculateDeltaPhase()
    {
        _deltaPhase = (_frequency * TAU / _sampleRate);
    }
}

