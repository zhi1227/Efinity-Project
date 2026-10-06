# Development note

`configure_project.py` and `configure_xml.py` record initial scaffolding and should not be rerun on this already configured project. `add_diagnostics.py` records a one-time patch, not an idempotent build step. Use run_tests.ps1 and build.ps1 for normal work.

The recorded manifest is evidence of a verified build. Running record_verified_build.py is appropriate only after reviewing all new RTL, completed current tests, and the latest resource/timing reports; it is not a substitute for those checks.

`apply_stability_update.py` and `fix_tracker_expiry.py` are historical one-time edit scripts; do not rerun them. `check_stability_golden.py` regenerates seven-scale simulation vectors and checks the quantized startup test count against the RTL; run it before simulation/build, not after generating a verified bitstream. The tracker unit test covers dropout, candidate order changes, per-face expiry, capacity, reacquisition and an expiry/matching race.

Latency revision: `generate_test.py` now generates 13-scale, four-phase references for ordinary, enlarged-face and blank inputs. Normal workflow remains reference generation -> run_tests.ps1 -> build.ps1 -> review -> record_verified_build.py -> program_jtag.ps1. Other apply/fix/record/document helper scripts are historical edit records and must not be run as a batch.
