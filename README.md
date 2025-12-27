# SENSI EEG Preproc — Bad Channel Detection Module

This repository contains a MATLAB module for semi-automated EEG bad-channel detection with an interactive review UI. The main entry point is `markSusChs.m`.

## Example data

Example (deidentified) EEG data used by `example.m` are hosted on the Stanford Digital Repository (SDR):

**Data location:**  
https://purl.stanford.edu/dg856vy8753

The `example.m` script downloads the data files from the SDR URLs into the local `ExampleData/` directory and then runs a demonstration analysis using `markSusChs.m`.

For full details about the dataset contents (file descriptions, variables, and notes), see the dataset README provided inside the `ExampleData` folder, or at the SDR link above.

## Quick start

1. Clone or download this repository.
2. Open MATLAB and add the repository (and subfolders) to your path.
3. Run: example.m