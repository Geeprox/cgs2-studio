// SPDX-License-Identifier: MIT
// Replacement Application::eventFilter, preserving the factory awake path.
// Emitted into verified unmapped file padding, with a new loader-backed byte.
// patched_* call and state references are resolved by build-touch-wake.py.
.section .text.wake,"ax",@progbits
.global wake_start,wake_end,flag_read,flag_clear,flag_set
.global call_manager,call_wake,call_touched,call_timer
wake_start:
    stp x29, x30, [sp, #-32]!
    mov x29, sp
    stp x19, x20, [sp, #16]
    mov x19, x0
    mov x20, x2
    ldrh w1, [x20, #16]
flag_read:
    adrp x9, 0
    add x9, x9, #0
    ldrb w10, [x9]
    cbz w10, classify
    // Consume the entire gesture which woke the screen, including synthesized
    // mouse events. No QML item receives its press, motion or release.
    cmp w1, #209                 // QEvent::TouchCancel (Qt 5 ABI)
    b.eq clear_gesture
    cmp w1, #2
    b.eq track_mouse
    cmp w1, #3                   // MouseButtonRelease
    b.eq end_mouse
    cmp w1, #194
    b.eq track_touch
    cmp w1, #196                 // TouchEnd
    b.eq end_touch
gesture_events:
    sub w2, w1, #2
    cmp w2, #3                   // Mouse press/release/double-click/move (2..5)
    b.ls consume
    sub w2, w1, #194
    cmp w2, #2                   // TouchBegin/Update/End
    b.ls consume
    b pass
track_mouse:
    orr w10, w10, #1
    b store_gesture
end_mouse:
    and w10, w10, #0xfffffffe
    b store_gesture
track_touch:
    orr w10, w10, #2
    b store_gesture
end_touch:
    and w10, w10, #0xfffffffd
store_gesture:
    strb w10, [x9]
    b consume
clear_gesture:
flag_clear:
    adrp x9, 0
    add x9, x9, #0
    strb wzr, [x9]
    b consume
classify:
    sub w2, w1, #2
    cmp w2, #1                   // Same factory set when there is no latch.
    b.ls screen_event
    sub w2, w1, #194
    cmp w2, #2
    b.hi pass
screen_event:
call_manager:
    bl .                         // ScreenManager::getInstance
    ldr x0, [x0]                 // Original QSharedPointer<ScreenManager>.
    ldrb w9, [x0, #0x4c]         // Exact native isScreenOn backing bool.
    cbnz w9, awake
    ldrh w1, [x20, #16]
    cmp w1, #2
    b.eq begin_wake
    cmp w1, #194
    b.ne consume                 // Release/motion never request wake.
begin_wake:
    cmp w1, #2
    mov w2, #1
    mov w3, #2
    csel w1, w2, w3, eq
flag_set:
    adrp x9, 0
    add x9, x9, #0
    strb w1, [x9]
call_wake:
    bl .                         // requestScreenOn only while native off.
    b consume
awake:
    // Unchanged original debounce and interfaceTouched notification path.
    ldr x0, [x19, #0x190]
    ldr w0, [x0, #0x10]
    tbz w0, #31, pass
    ldr x0, [x19, #0x150]
call_touched:
    bl .                         // GlobalController::interfaceTouched
    ldr x0, [x19, #0x190]
call_timer:
    bl .                         // QTimer::start
pass:
    mov w0, #0
    b finish
consume:
    ldrb w0, [x20, #18]
    and w0, w0, #0xfffffffb       // Same factory accepted-bit handling.
    strb w0, [x20, #18]
    mov w0, #1
finish:
    ldp x19, x20, [sp, #16]
    ldp x29, x30, [sp], #32
    ret
wake_end:
