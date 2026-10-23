// SPDX-License-Identifier: MIT
// CGS2 firmware 4.5.6_0167, ScreenAPI::getBrightness(int), 0x599dc0.
// LUT uses the factory filtered sensor value. x0 is ScreenAPI*, w1 is lux.
.section .text.curve,"ax",@progbits
.global curve_start, curve_end, sensor_store
curve_start:
    ldr w8, [x0, #0x3c]     // Previously accepted target for hysteresis.
    cmp w1, #0
    b.lt hold
    mov w0, #1000
    cmp w1, #1500
    b.ge hysteresis
    adr x2, knots
    ldp w3, w4, [x2], #8
next_knot:
    ldp w5, w6, [x2], #8
    cmp w1, w5
    b.le interpolate
    mov w3, w5
    mov w4, w6
    b next_knot
interpolate:
    sub w1, w1, w3
    sub w5, w5, w3
    sub w6, w6, w4
    mul w1, w1, w6
    udiv w1, w1, w5
    add w0, w4, w1
hysteresis:
    subs w1, w0, w8
    cneg w1, w1, mi
    cmp w1, #20
    csel w0, w8, w0, le
    ret
hold:
    mov w0, w8
    ret
knots:
    .word 0,80, 3,100, 10,180, 50,520, 300,800, 900,950, 1500,1000
// Called at 0x59a050 instead of the unconditional lux store. QString::toInt
// writes success to spare stack byte 0x50; read errors retain existing lux.
sensor_store:
    ldrb w1, [sp, #0x50]
    cmp w0, #0
    ccmp w1, #0, #4, ge
    b.eq sensor_return
    str w0, [x25, #0x40]
sensor_return:
    ret
curve_end:

// ScreenAPI::adjustBrightness(), 0x59a760. Same stack frame as factory.
// Preserve the factory 30 ms timer, snap at the target to avoid overshoot.
.section .text.adjust,"ax",@progbits
.global adjust_start, adjust_end, call_stop, call_signal, call_write
adjust_start:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    str x19, [sp, #16]
    mov x19, x0
    ldp w2, w3, [x0, #0x38]
    subs w4, w3, w2
    mov w5, #12
    mov w6, #3
    csel w5, w5, w6, gt
    cneg w6, w4, mi
    cmp w6, w5
    b.le arrived
    cmp w4, #0
    cneg w5, w5, mi
    add w2, w2, w5
    str w2, [x19, #0x38]
    b emit_value
arrived:
    str w3, [x19, #0x38]
    ldr x0, [x19, #0x20]
call_stop:
    bl .
emit_value:
    ldr w1, [x19, #0x38]
    mov x0, x19
call_signal:
    bl .
    ldr w1, [x19, #0x38]
    mov x0, x19
    ldr x19, [sp, #16]
    ldp x29, x30, [sp], #32
call_write:
    b .
adjust_end:
