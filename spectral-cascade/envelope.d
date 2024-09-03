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
    }

    void trigger(float releaseTime)
    {
        this.releaseTime = releaseTime;
        trigger();
    }

    void trigger()
    {
        _currentLevel = 1.0f;
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
