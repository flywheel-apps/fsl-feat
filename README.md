[![Docker Pulls](https://img.shields.io/docker/pulls/flywheel/fsl-feat.svg)](https://hub.docker.com/r/flywheel/fsl-feat/)
[![Docker Stars](https://img.shields.io/docker/stars/flywheel/fsl-feat.svg)](https://hub.docker.com/r/flywheel/fsl-feat/)

## flywheel/fsl-feat

Build context for a [Flywheel Gear](https://github.com/flywheel-io/gears/tree/master/spec) to execute FSL's FEAT.

This Gear uses a simple `.fsf` file that performs basic preprocessing.
This includes the following steps, all of which are optional (see `manifest.json`):

1) Initial Volume Removal   (default 0 volumes)
1) Motion Correction        (default YES)
2) Slice Timing Correction  (default YES, must specify acquisition order)
3) Spatial Smoothing        (default 5mmFWHM)
4) Intensity Normalization  (default YES)
5) High-Pass Filtering      (default 100s cutoff)
6) Brain extraction         (default YES)
7) Registration to standard (default YES)
   - Registration to alternate templates is supported when a Standard Template is specified AND the Use alt template option is set to 1 (true).
8) Low_pass Filtering       (default NO)
