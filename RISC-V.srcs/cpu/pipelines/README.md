Pipelines
=========

These pipelines provide various facilities, such as a simple pipeline;
out-of-order execution; or speculative execution.

# Simple Pipeline

The basic pipeline uses a buffered handshake to indicate readiness. The
buffer avoids taking a cycle to set `BUSY`, allowing the sender to send
any time `BUSY` is not set.  The receiver must accept data immediately,
so if it is a clock late setting `BUSY` it buffers the data.

This pipeline uses the following paradigm:

```
Fetch→Decode→Load→Execute→Mem→Retire
```

The `Decode` stage identifies the type of instruction and passes on
simplified information about what registers to load, how to pull the
immediate data, and so forth.

The `Load` stage tracks forward dependencies and waits for any register
writes to complete.

The `Execute` stage executes the instruction.  RISC-V executes everything
from registers, and only accesses memory by load and store instructions,
so the `Execute` stage is a no-op when accessing memory.

The `Mem` stage accesses memory, while the `Retire` stage writes out
changed registers.

## Instruction Translation
An enhancement on this pipeline allows instruction translation:

```
Fetch→Translate→Decode→Load→Execute→Mem→Retire
```

The `Translate` stage can interpret `RVC` instructions, sending expanded
instructions to the `Decode` phase.

The `Translate` stage is flexible:  a `Translate` decoder combined with
a special status flag can decode `IA-32` and `x86-64` instructions to
RISC-V equivalents, storing special registers such as the `Flags`
register in available RISC-V registers.  Because the instructions are
decoded to RISC-V internally, all branches, jumps, and other addresses
are valid as-is.

Changing into and out of `Supervisor` or `User` mode works the same way.
An OS aware of the translation option can switch to any `Translate`
status; and a bootloader can switch translation status to boot a
non-native OS, which in turn can recognize an available RISC-V mode and
use it to execute RISC-V software.

Cross-architecture translation is a generally heavy lift, but is a viable
method for implementing a different processor architecture.

# Out-of-order execution

Any pipeline can execute instructions out-of-order.  The `Load` stage
must track forward dependencies and not move an instruction to `Execute`
until a prior instruction has written any register on which the new
instruction depends.  In OOE, the `Load` stage simply buffers the
instruction with notation on its dependencies and accepts the next,
repeating this process until it runs out of buffer space, finds an
instruction without forward dependencies, or determines a standing
instruction has no remaining dependencies.

## Superscalar Execution

Out-of-Order pipelines can distribute instructions to multiple
`Execute` stages.  One possible implementation would have `Fetch`
retrieve multiple instructions and distribute them to several
decoders, each attached to a separate port on the `Load` stage.
The `Load` stage would then determine dependencies, buffer
instructions, and simultaneously fetch registers.
