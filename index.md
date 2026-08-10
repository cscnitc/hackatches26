# Hack@CHES 2026 - Phase 1 Bug Submissions

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
