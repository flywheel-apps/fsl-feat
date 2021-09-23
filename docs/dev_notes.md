## FSL Options
1) Melodic ("inmelodic") => recommended by FSL for quick eval of motion artifacts, if nothing else
   - Probably should automatically include the QA feat_output_directory.feat/filtered_func_data.ica/report/00index.html, even if we don't have a Melodic denoising gear
   - Option for Melodic ICA data exploration is 0, make flexible?
2) Analysis level will remain hard-coded for First-level for now
3) Stages are fixed to Pre-processing (#1) only for now
4) pre-stats processing => recommended default to be on, but should this be optional?
5) Prewhitening is set to true and should remain this way, until/unless perfusion studies are being analyzed
6) DOF: change the later to be optional 
```
   # Degrees of Freedom for registration to main structural  
   set fmri(reghighres_dof) BBR  
   # Degrees of Freedom for registration to standard space
   set fmri(regstandard_dof) 12
``` 
7) Search space is currently set to default 90. Seems like this is sufficient, but may consider adding optional config (fetal scans/special FOV for hypothalamus)?
8) FNIRT is currently disabled; not highly recommended, but should this be an option?
```# Do nonlinear registration from structural to standard space?
set fmri(regstandard_nonlinear_yn) 0
```
