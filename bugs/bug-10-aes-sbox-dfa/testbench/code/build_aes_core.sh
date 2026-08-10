#!/bin/bash
# Build real aes_cipher_core standalone under VCS (DFA target, bug #17).
set -e
OT=/home/nitc2026/opentitan/opentitan
AES=$OT/hw/ip/aes/rtl
PR=$OT/hw/ip/prim/rtl
ED=$OT/hw/ip/edn/rtl
CS=$OT/hw/ip/csrng/rtl
ES=$OT/hw/ip/entropy_src/rtl
KM=$OT/hw/ip/keymgr/rtl
LC=$OT/hw/ip/lc_ctrl/rtl
PW=~/vcs_work/rtl/prim
FI=~/vcs_work/fi
cd $FI

export VCS_HOME=/home/synopsys/tools/vcs/U-2023.03
export SNPSLMD_LICENSE_FILE=27020@14.139.1.126
export PATH=/home/synopsys/tools/vcs/U-2023.03/bin:$HOME/bin:$PATH

vcs -full64 -sverilog +acc+3 +define+SIMULATION \
  +incdir+$PR +incdir+$AES +incdir+$ED +incdir+$ES +incdir+$CS +incdir+$KM +incdir+$LC +incdir+$PW +incdir+$FI \
  $PW/prim_util_pkg.sv $PW/prim_mubi_pkg.sv \
  $ES/entropy_src_pkg.sv $CS/csrng_pkg.sv $ED/edn_pkg.sv \
  $PR/prim_secded_pkg.sv $PR/prim_count_pkg.sv \
  $AES/aes_reg_pkg.sv $LC/lc_ctrl_state_pkg.sv $LC/lc_ctrl_reg_pkg.sv $LC/lc_ctrl_pkg.sv \
  $KM/keymgr_reg_pkg.sv $KM/keymgr_pkg.sv \
  $AES/aes_pkg.sv $AES/aes_sbox_canright_pkg.sv \
  $FI/prim_flop.sv $FI/prim_flop_en.sv $FI/prim_buf.sv $FI/prim_flop_2sync.sv \
  $PR/prim_sparse_fsm_flop.sv $PR/prim_mubi4_sender.sv \
  $PR/prim_sec_anchor_buf.sv $PR/prim_sec_anchor_flop.sv \
  $PR/prim_assert.sv $PR/prim_count.sv \
  $PR/prim_trivium_pkg.sv $PR/prim_trivium.sv \
  $AES/aes_sbox_canright.sv $AES/aes_sbox_canright_masked.sv $AES/aes_sbox_lut.sv \
  $AES/aes_sbox_canright_masked_noreuse.sv \
  $AES/aes_sbox_dom.sv $AES/aes_sbox.sv $AES/aes_sub_bytes.sv \
  $AES/aes_cipher_control_fsm.sv $AES/aes_cipher_control_fsm_p.sv $AES/aes_cipher_control_fsm_n.sv \
  $AES/aes_cipher_control.sv $AES/aes_key_expand.sv $AES/aes_prng_masking.sv $AES/aes_sel_buf_chk.sv \
  $AES/aes_mix_columns.sv $AES/aes_mix_single_column.sv $AES/aes_shift_rows.sv \
  $AES/aes_cipher_core.sv \
  "$1" \
  -o "$2" -l compile_$2.log 2>&1 | tail -25
