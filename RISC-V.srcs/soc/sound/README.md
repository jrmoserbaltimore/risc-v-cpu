Sound
=====

This sound chip provides audio.

# IHDA

The sound chip implements the Intel High-Definition Audio specification.

# Synthesis

This sound chip provides a synthesizer, the MSFOPL5, providing complex
FM, pulse, and sample-driven synthesis.

## FM Synthesis

The MSF FM Operator type-L, version 5, incorporates an extended FM
synthesis register interface compatible with the OPL3 and OPL4.  When
setting OPL3-enable register DD, Status register D1 is set to 1 to
indicate OPL5 mode.

### Enhanced Stereo

In OPL5 mode, bits D7 through D5 of the C9-CF registers set the stero
pan.  000 indicates full panning, while 111 indicates 1/16 step from
full, 110 indicates 2/16 step from the full, and so forth.  Bits D4-D3
indicate pan speed:  when the panning level is changed, the change
occurs gradually for this amount of time, higher being slower.  When all
of these bits are set to 0, stereo operates as normal OPL3.

Stereo is centered whenever both the right and left channel are enabled.
When one channel is disabled, the stereo pans according to the stereo
pan setting.  Stereo pan sets the disabled channel to an interval of
1/16 the output level.

Setting bit D4 decreases the on channel in inverse to the off channel.
When the left channel is enabled and pan is set to 001, the right
channel's output level is 1/16 the configured output level; when D4 is
set, the left channel's output level is 15/16 the output level.  A full,
smooth pan is possible by moving the pan to 111, then setting the output
level to half and enabling both channels, then restoring the output
level and disabling the left channel, and finally counting down from 111
to 000.  This provides a smooth pan not possible by simply manipulating
the output level, as doing so would reduce the toal volume of both
channels.

The OPL5 provides fine-grained stereo pan speed by setting the pan speed
between 0 and 3 and then the stereo pan registers from 0 to 15 (which in
practice act as 8 down to 1, with centered being 0).

The slowest uniform pan is achieved at pan speed 3 and an increase of
pan (decrease the value in the register) by 1 at this interval.  The
OPL5 changes the stereo pan over the same interval no matter the
degree, so panning is faster when changing the pan by more than 1, or
when switching from one channel to center, and even faster when
switching from one channel to the other.

Advanced stereo is available only on channels 2 through 8 of each
register bank due to the ninth channel using the resource for channel 1.

### Additional Waveforms

The waveform select on the E0-F5 registers is extended to D3.  This
enables additional waveforms:

* 8:  Triangle (sharp sine)
* 11: True sawtooth

## Additional channels

The OPL5 provides two more sets of registers providing six-operator
selection.  Six bits of SynthTyp provides 64 operator configurations per
channel.  Each additional register block provides two six-operator
channels and one four-operator channel.
