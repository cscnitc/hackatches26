Here we, [KattangalSec](https://kattangalsec.in/), document the 17 bugs we managed to find for the challenge. We used a combination of methods for finding bugs. Initially, we relied on a fuzzing approach, trying to apply existing RISC-V based fuzzers and techniques, researching online via arXiv, and [Connected Papers](https://connectedpapers.com). Most of those attempts went in vain. However, we were able to find [3 bugs](./vcs-pipeline.md) later on through fuzzing. We also modified [Mjolnir](https://github.com/chipsalliance/mjolnir) and created [Lightsaber](./lightsaber.md) and were able to be gather the majority of the bugs we have listed below.

Almost all of our work was done agentically, with us, the human, acting usually as a supervisor, and guiding the agent. Our preferred choice of harness was [Hermes](https://hermes-agent.nousresearch.com/) which acted as the principal orchestrator, documenting and writing exploits and testbenches. [OpenCode](https://opencode.ai/) was also used. We estimate our total AI related API costs to be less than $10 dollars, which was possible due to the generous limits of OpenCode's Go subscription as well as AgentRouter's promotional free offer granting $200 credits for GPT 5.6 Sol.

## Bugs

1. [PMP error output always zero](bugs/bug-01-pmp-bypass/README.md)
2. [CTN access-range check overridden](bugs/bug-02-ctn-range-bypass/README.md)
3. [Key Manager source-key validity gate](bugs/bug-03-keymgr-source-valid/README.md)
4. [AES DPA masking forceable off](bugs/bug-04-aes-force-masks/README.md)
5. [Debug module auth hardwired to 1](bugs/bug-05-dm-no-auth/README.md)
6. [Lifecycle token compared on 32 bits](bugs/bug-06-lc-token-trunc/README.md)
7. [LC transition check OR instead of AND](bugs/bug-07-lc-or-vs-and/README.md)
8. [LcStProd in two unique case branches](bugs/bug-08-lcstprod-duplicate/README.md)
9. [AES output register reset bypass](bugs/bug-09-aes-reset-bypass/README.md)
10. [AES S-Box DOM counter fault, DFA key recovery](bugs/bug-10-aes-sbox-dfa/README.md)
11. [KeyMgr EDN error path unconnected](bugs/bug-11-edn-err-unconnected/README.md)
12. [KeyMgr FSM illegal state silent recovery](bugs/bug-12-fsm-silent-recovery/README.md)
13. [CSRNG unmasked AES (state leak)](bugs/bug-13-csrng-unmasked/README.md)
14. [ROM controller single-bit digest compare](bugs/bug-14-rom-ctrl-compare/README.md)
15. [Entropy Markov health test dead](bugs/bug-15-entropy-markov/README.md)
16. [CSRNG key not zeroized after op](bugs/bug-16-csrng-key-remanence/README.md)
17. [OTBN URND reseed ignores EDN error](bugs/bug-17-otbn-urnd-err/README.md)

---

## Note on testbenches

The module-level testbenches use the synthesizable stimulus-FSM + `main_manual.cpp` pattern
(Verilator 4.210's `--main` harness does not advance time, so the C++ harness toggles
`top-clk` explicitly; reset is held 2 cycles, then the FSM runs to completion and prints
the result):

```bash
verilator -Wno-fatal -Wno-WIDTH -Wno-UNUSED -Wno-IMPLICIT -Wno-CASEINCOMPLETE \
  -Wno-DECLFILENAME -Wno-PINMISSING -Wno-MODDUP -Wno-UNOPTFLAT -Wno-MULTIDRIVEN \
  --cc --exe --top-module tb +incdir+<ip>/rtl +incdir+... \
  <pkg/prim files in dependency order> <module>.sv <module>_tb.sv main_manual.cpp
make -C obj_dir -f Vtb.mk
./obj_dir/Vtb
```

Dependency notes: packages must precede modules (e.g. `prim_util_pkg` before `prim_*`);
generated/abstract prims come from the fuseSoC/primgen build at
`hw/build.verilator_real/src/lowrisc_prim_abstract_*`. All referenced RTL is the
competition OpenTitan RTL at the given paths.
