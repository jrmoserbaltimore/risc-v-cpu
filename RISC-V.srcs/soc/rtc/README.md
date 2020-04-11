Real-Time Clock
===============

This provides the real-time clock function.

Standard RTC modules are extremely-accurate and output IRQ pulses at 1Hz or
512Hz.

This RTC uses a 32.768KHz crystal oscillator to drive the RTC circuit.  This
also provides a clock input, which the internal PLL raises to above 1MHz.

When running, the RTC provides a pulse at either 1Hz or 512Hz.  In either
configuration, this real-time clock function assumes the 32.768KHz clock is
100% accurate and uses this to adjust any drift in the RTC.  The frequency
from the PLL is measured against the IRQ and used to determine the nearest
micro-second since January 1, 1970 to provide `time` and `mtime`.

Writes to `mtime` adjust the RTC to the Unix time in microseconds given.

