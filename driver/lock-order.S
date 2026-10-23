// SPDX-License-Identifier: GPL-2.0-only
// CGS2 skw 2.0.240112.fcefe00 only; offsets verified against shipped DWARF.
// Argument: &iface->sta.core.lock (iface + 0x8b0).
// &iface->wdev.mtx = iface + 0xb0 = core - 0x800.
.text
.p2align 2
.global cgs2_sta_lock_order
.type cgs2_sta_lock_order, %function
cgs2_sta_lock_order:
    stp x19, x30, [sp, #-16]!
    mov x19, x0
    sub x0, x19, #0x800
    bl mutex_lock
    mov x0, x19
    bl mutex_lock
    ldp x19, x30, [sp], #16
    ret
.size cgs2_sta_lock_order, .-cgs2_sta_lock_order
.global cgs2_sta_unlock_order
.type cgs2_sta_unlock_order, %function
cgs2_sta_unlock_order:
    stp x19, x30, [sp, #-16]!
    mov x19, x0
    bl mutex_unlock
    sub x0, x19, #0x800
    bl mutex_unlock
    ldp x19, x30, [sp], #16
    ret
.size cgs2_sta_unlock_order, .-cgs2_sta_unlock_order
