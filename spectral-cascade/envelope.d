import std.algorithm : min, max;


struct Envelope
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
