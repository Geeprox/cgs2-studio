// SPDX-License-Identifier: MIT
// Transient output cap. Ordinary brightness setters and stored values retain
// their original paths. Commands are queued through the existing Qt signal.
.section .text.dim,"ax",@progbits
.global manager,runner,writer,wake
.global manager_signal,manager_continue,runner_continue,runner_write
.global state_runner,state_writer,state_wake,writer_continue,wake_continue
manager:
    cmn w1, #1000
    b.eq .Lmanager_dispatch
    cmn w1, #1001
    b.eq .Lmanager_dispatch
    ldr w2, [x0, #0x14]
manager_continue:
    b .
manager_signal:
.Lmanager_dispatch:
    b .
runner:
    cmn w1, #1000
    b.eq command
    cmn w1, #1001
    b.eq command
    ldrb w3, [x0, #0x74]
runner_continue:
    b .
command:
    cmn w1, #1001
    cset w10, eq
state_runner:
    adrp x9, 0
    add x9, x9, #0
    strb w10, [x9]
    ldr x0, [x0, #0x10]
    ldr w1, [x0, #0x38]
runner_write:
    b .
writer:
state_writer:
    adrp x9, 0
    add x9, x9, #0
    ldrb w10, [x9]
    cbz w10, write_original
    // 1/4 of the current automatic/manual target, bounded at 80..200.
    // min(input, cap) preserves existing low values and screen-off zero.
    asr w11, w1, #2
    mov w12, #80
    cmp w11, w12
    csel w11, w12, w11, lt
    mov w12, #200
    cmp w11, w12
    csel w11, w12, w11, gt
    cmp w1, w11
    csel w1, w1, w11, lt
write_original:
    ldrb w0, [x0, #0x48]
writer_continue:
    b .
wake:
state_wake:
    adrp x9, 0
    add x9, x9, #0
    strb wzr, [x9]
    mov w2, #1
wake_continue:
    b .
