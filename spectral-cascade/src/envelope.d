import std.algorithm : min, max;


struct Attack
{
nothrow @nogc:
public:

    @property float attackTime() { return m_attackTime; }
    @property float attackTime(float attackTime)
    {
        m_attackTime = attackTime;
        if (attackTime==0)
            _attackRate = 1.0f;
        else
            _attackRate = 1.0f / (attackTime * _sampleRate);
        return attackTime;
    }

    void reset(float sampleRate)
    {
        _sampleRate = sampleRate;
        attackTime = 0.0f;
        _isAttacking = false;
    }

    /// prepare the enveloppe to be triggered again
    void rearm()
    {
        _isAttacking = false;
        _currentLevel = 0.0f;
    }


    void trigger(float attackTime)
    {
        this.attackTime = attackTime;
        trigger();
    }

    void trigger()
    {
        _currentLevel = 0.0f;
        _isAttacking = true;
    }

    float process()
    {
        if (_isAttacking)
        {
            _currentLevel += _attackRate;
            if (_currentLevel >= 1.0f)
            {
                _currentLevel = 1.0f;
                _isAttacking = false;
            }
        }
        
        return _currentLevel;
    }

private:
    float _sampleRate = 48000.0f;
    float m_attackTime = 0.0f;
    float _currentLevel = 0.0f;
    float _attackRate = 0.0f;
    bool _isAttacking = false;

}


struct Release
{
nothrow @nogc:
public:
    bool isReleasing = false;

    bool isReleased() { return _currentLevel == 0.0f; }

    @property float releaseTime() { return m_releaseTime; }
    @property float releaseTime(float releaseTime)
    {
        m_releaseTime = releaseTime;
        if (releaseTime==0)
            _releaseRate = 1.0f;
        else
            _releaseRate = 1.0f / (releaseTime * _sampleRate);
        return releaseTime;
    }

    void reset(float sampleRate)
    {
        _sampleRate = sampleRate;
        releaseTime = 0.0f;
        isReleasing = false;
        _currentLevel = 1.0f;
    }

    /// prepare the enveloppe to be triggered again
    void rearm()
    {
        isReleasing = false;
        _currentLevel = 1.0f;
    }

    void trigger(float releaseTime)
    {
        this.releaseTime = releaseTime;
        trigger();
    }

    void trigger()
    {
        isReleasing = true;
    }

    float process()
    {
        if (isReleasing)
        {
            _currentLevel -= _releaseRate;
            if (_currentLevel <= 0.0f)
            {
                _currentLevel = 0.0f;
                isReleasing = false;
            }
        }
        
        return _currentLevel;
    }

private:
    float _sampleRate = 48000.0f;
    float m_releaseTime = 0.0f;
    float _currentLevel = 1.0f;
    float _releaseRate = 0.0f;
}

unittest
{
    Release r;

    assert(!r.isReleasing);
    assert(!r.isReleased);

    r.reset(3);
    assert(!r.isReleasing);
    assert(!r.isReleased);

    r.trigger(1);
    assert(r.isReleasing);
    assert(!r.isReleased);

    r.process();
    assert(r.isReleasing);
    assert(!r.isReleased);

    r.trigger(1);
    assert(r.isReleasing);
    assert(!r.isReleased);

    r.process(); // extra process to make sure it's over despite rounding
    assert(r.process() == 0);
    assert(!r.isReleasing);
    assert(r.isReleased);

    r.reset(2);
    assert(!r.isReleasing);
    assert(!r.isReleased);

    r.trigger(1);
    assert(r.isReleasing);
    assert(!r.isReleased);

    assert(r.process() > 0);
    assert(r.isReleasing);
    assert(!r.isReleased);

    r.process(); // extra process to make sure it's over despite rounding
    assert(r.process() == 0);
    assert(!r.isReleasing);
    assert(r.isReleased);

}
