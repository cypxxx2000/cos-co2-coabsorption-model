<img width="920" height="593" alt="image" src="https://github.com/user-attachments/assets/26ba16f7-0079-4f86-88b5-334952c9be15" /># cos-co2-coabsorption-model
# MATLAB User Guide for Multicomponent Gas Competitive Co-absorption Models

**Applicable programs:**

1. `calucatemodel.m`
2. `calucatemodelmix.m`
3. `calucatemodelCO2CS2.m`
4. `calucatemodelCO2COSCS2.m`

## 1. Program Overview and Model Selection

All four programs are closed-system static equilibrium absorption models. Each program reads the input parameters from an Excel spreadsheet row by row, solves a nonlinear system of equations for each operating case, and outputs the equilibrium gas-phase residual amounts, liquid-phase concentrations, reaction product concentrations, absorption amounts, and solver diagnostics.

These programs do not calculate time-dependent absorption profiles or mass transfer rates.

### 1.1 `calucatemodel.m`: Single-Amine COS–CO2 System

This program models the competitive co-absorption of COS and CO2 in a single-amine solution.

The model considers:

- Physical dissolution of CO2 and COS.
- Adduct formation between CO2 and the amine.
- Adduct formation between COS and the amine.
- Amine-promoted COS hydrolysis.

The hydrolysis closure relation is defined as:

`[AH+] = [HS-] = x`

The unknown variables are the gas-phase amounts of CO2 and COS and the free amine concentration.

### 1.2 `calucatemodelmix.m`: Mixed-Amine COS–CO2 System

This program models COS–CO2 co-absorption in a mixed solution containing two amines, designated as amine A and amine B.

The model considers:

- Physical dissolution of CO2 and COS.
- CO2 and COS adduct formation with amine A.
- CO2 and COS adduct formation with amine B.
- COS hydrolysis promoted by both amines.

The unknown variables are the gas-phase amounts of CO2 and COS and the free concentrations of amines A and B.

### 1.3 `calucatemodelCO2CS2.m`: Binary CO2–CS2 System

This program models the competitive co-absorption of CO2 and CS2.

The model considers:

- Physical dissolution of CO2 and CS2.
- CO2 adduct formation with the amine.
- CS2 adduct formation with the amine.

CS2 hydrolysis and COS formation are not considered.

The unknown variables are the gas-phase amounts of CO2 and CS2 and the free amine concentration.

### 1.4 `calucatemodelCO2COSCS2.m`: Ternary CO2–COS–CS2 System

This program models the competitive co-absorption of CO2, COS, and CS2.

The model considers:

- Physical dissolution of all three gases.
- Adduct formation between each gas and the amine.
- COS hydrolysis.

CS2 hydrolysis and the conversion of CS2 into COS are not considered.

The unknown variables are the gas-phase amounts of CO2, COS, and CS2, the free amine concentration, and the COS hydrolysis progress variable `xCOS`.

**Important:** The model assumptions described above reflect the reactions currently implemented in the MATLAB scripts. If additional reactions occur in the actual system but are not included in the code, systematic deviations in the model predictions may arise.

## 2. Running the Programs

### 2.1 Basic Workflow

1. Open MATLAB and set the current working directory to the folder containing the `.m` files.
2. Ensure that MATLAB can access `fsolve` and `optimoptions`. The Optimization Toolbox is generally required.
3. Enter the name of the corresponding script in the MATLAB Command Window. For example:

   - `calucatemodel`
   - `calucatemodelmix`
   - `calucatemodelCO2CS2`
   - `calucatemodelCO2COSCS2`

   Run the selected program individually.

4. When the file selection dialog appears, select the Excel parameter file (`.xlsx` or `.xls`).
5. The program processes the input cases row by row and displays the solver information in the MATLAB Command Window.
6. After the calculations are completed, the output TXT and CSV files are saved in the same directory as the selected Excel input file.

### 2.2 Important Notes

- By default, the programs read the first worksheet of the Excel file (`sheetName = 1`).
- Each row represents an independent calculation case.
- Output filenames are fixed. Existing files with the same names in the output directory may be overwritten. Back up previous results before running the programs again.
- The actual script filenames should be used when executing the programs.

## 3. Excel Input Parameters

### 3.1 Definitions of Common Parameters

| Parameter | Description | Unit / Format |
|---|---|---|
| `R` | Universal gas constant | Consistent with pressure and volume units |
| `T` | Temperature | K |
| `Vg` | Gas-phase headspace volume | Consistent volume unit |
| `VL` | Liquid-phase volume | L when concentrations are in mol/L |
| `CLtot` | Liquid-phase concentration-scale parameter in the Henry's law relationship, as defined in the original model | As defined in the model |
| `CA0` | Initial total concentration of amine A | mol/L |
| `CB0` | Initial total concentration of amine B; required only for the mixed-amine model | mol/L |
| `ng0` | Initial total gas-phase amount | mol |
| `yCO20` | Initial CO2 mole fraction | 0–1 |
| `yCOS0` | Initial COS mole fraction | 0–1 |
| `yCS20` | Initial CS2 mole fraction | 0–1 |
| `HCO2` | Henry's law parameter for CO2; the code comments use bar | As defined in the model |
| `HCOS` | Henry's law parameter for COS; the code comments use bar | As defined in the model |
| `HCS2` | Henry's law parameter for CS2; the code comments use bar | As defined in the model |
| `KCO2` | Equilibrium constant for amine–CO2 adduct formation | As defined in the model |
| `KCOS` | Equilibrium constant for amine–COS adduct formation | As defined in the model |
| `KCS2` | Equilibrium constant for amine–CS2 adduct formation | As defined in the model |
| `Khyd` | COS hydrolysis equilibrium constant in the single-amine COS–CO2 model | As defined in the model |
| `KhydA`, `KhydB` | COS hydrolysis equilibrium constants associated with amines A and B in the mixed-amine model | As defined in the model |
| `KhydCOS` | COS hydrolysis equilibrium constant in the ternary model | As defined in the model |

The units and numerical values of all equilibrium constants must be consistent with the corresponding equilibrium expressions and concentration definitions implemented in the code. Units should not be inferred solely from parameter names or adopted directly from other literature without verification.

### 3.2 Required Excel Columns for Each Program

**1. `calucatemodel.m`**

Required columns:

```text
R, T, Vg, VL, CLtot, CA0, ng0,
yCOS0, yCO20, HCOS, HCO2, KCO2, KCOS, Khyd
```

**2. `calucatemodelmix.m`**

Required columns:

```text
R, T, Vg, VL, CLtot, ng0, yCO20, yCOS0, HCO2,
HCOS, CA0, CB0, KCO2A, KCOSA, KhydA,
KCO2B, KCOSB, KhydB
```

This program supports certain column aliases and case-insensitive column-name matching. However, using the standard column names listed above is recommended.

**3. `calucatemodelCO2CS2.m`**

Required columns:

```text
R, T, Vg, VL, CLtot, CA0, ng0, yCO20, yCS20,
HCO2, HCS2, KCO2, KCS2
```

This program does not require `HCOS`, `KhydCS2`, or `yCOS0`.

**4. `calucatemodelCO2COSCS2.m`**

Required columns:

```text
R, T, Vg, VL, CLtot, CA0, ng0, yCO20,
yCOS0, yCS20, HCO2, HCOS, HCS2,
KCO2, KCOS, KCS2, KhydCOS
```

This program does not require `KhydCS2`.

### 3.3 Optional Columns

The following optional columns can be included:

| Column | Description |
|---|---|
| `Solvent` | Solvent name |
| `MassConc` | Solvent concentration label |

These columns are primarily used to identify and label the calculation cases. They do not directly enter the equilibrium equations.

The code recognizes certain alternative column names, including some Chinese aliases such as "溶剂分子", "溶剂", "质量浓度", and "浓度".

For consistency and compatibility, English column names are recommended.

### 3.4 Gas-Phase Mole Fractions

The initial amount of each gas component is calculated as:

`n_i,0 = ng0 × y_i,0`

For example:

- 80 mol% CO2 should be entered as `yCO20 = 0.80`.
- 1000 ppm COS should be entered as `yCOS0 = 0.001`.

Gas concentrations must be entered as mole fractions between 0 and 1, rather than as ppm or mol% numerical values.

The sum of the initial gas-phase mole fractions must not exceed 1. The remaining fraction is treated as an inert gas for the calculation of the total gas-phase pressure.

The programs do not automatically correct invalid mole fractions. All input compositions should therefore be checked before calculation.

## 4. Units and Fundamental Relationships

The gas-phase partial pressure is calculated as:

`P_i = n_i,g × R × T / Vg`

The liquid-phase concentration of a free dissolved gas component is calculated as:

`c_i = CLtot × P_i / H_i`

One internally consistent unit system is:

| Variable | Unit |
|---|---|
| `R` | 0.08314 L·bar·mol⁻¹·K⁻¹ |
| `Vg`, `VL` | L |
| `T` | K |
| `n` | mol |
| Concentration | mol/L |
| `P` and `H` | bar |

If a different unit system is used in the original model, all related quantities must remain consistent.

In particular, the definitions of `CLtot`, Henry's law parameters, and reaction equilibrium constants must be consistent with the equations implemented in the code.

## 5. Overview of the Model Equations

### 5.1 Single-Amine COS–CO2 Model

The adduct formation equilibria are:

`[ACOOH] = KCO2 × a × c`

`[ACOSH] = KCOS × a × s`

The COS hydrolysis relationship is:

`x = sqrt(Khyd × a × s / c)`

The hydrolysis-related concentrations satisfy:

`[AH+] = [HS-] = x`

These relationships are solved simultaneously with the amine, CO2, and COS mass balances.

### 5.2 Mixed-Amine COS–CO2 Model

The model separately calculates the following adduct species:

- `ACOOH`
- `ACOSH`
- `BCOOH`
- `BCOSH`

COS hydrolysis contributions from amines A and B are calculated using `KhydA` and `KhydB`, respectively.

The corresponding amine A, amine B, CO2, and COS mass balances are solved simultaneously.

### 5.3 Binary CO2–CS2 Model

The adduct formation equilibria are:

`[ACOOH] = KCO2 × a × c`

`[ACSSH] = KCS2 × a × d`

COS hydrolysis is not included.

The amine, CO2, and CS2 mass balances are solved simultaneously.

### 5.4 Ternary CO2–COS–CS2 Model

The adduct formation equilibria are:

`[ACOOH] = KCO2 × a × c`

`[ACOSH] = KCOS × a × s`

`[ACSSH] = KCS2 × a × d`

The COS hydrolysis equilibrium is expressed as:

`xCOS^2 × c - KhydCOS × a × s = 0`

This equation is solved simultaneously with the amine, CO2, COS, and CS2 mass balances.

## 6. Output Files and Key Variables

Each program generates two output files: a CSV file and a tab-delimited TXT file.

### 6.1 Output Filenames

**`calucatemodel.m`**

```text
results_static_adduct_plus_hydrolysis.txt
results_static_adduct_plus_hydrolysis.csv
```

**`calucatemodelmix.m`**

```text
results_static_mixAB_adduct_plus_hydrolysis.txt
results_static_mixAB_adduct_plus_hydrolysis.csv
```

**`calucatemodelCO2CS2.m`**

```text
results_static_CO2_CS2_adduct_only.txt
results_static_CO2_CS2_adduct_only.csv
```

**`calucatemodelCO2COSCS2.m`**

```text
results_static_CO2_COS_CS2_no_CS2_hydrolysis.txt
results_static_CO2_COS_CS2_no_CS2_hydrolysis.csv
```

### 6.2 Key Output Variables

| Variable | Description | Unit |
|---|---|---|
| `CaseID` | Calculation case identifier corresponding to the input row | — |
| `Solvent` | Solvent name | — |
| `MassConc` | Solvent concentration label | — |
| `Temperature_K` | Temperature | K |
| `Solved` | Indicates whether the case satisfies the specified residual convergence criterion | Logical |
| `Tries` | Number of solver attempts | — |
| `Exitflag` | `fsolve` exit flag; should be interpreted together with the residuals | — |
| `u1`, `u2`, `u3` | Equilibrium gas-phase amounts of CO2, COS, and/or CS2, depending on the program | mol |
| `a`, `b` | Free amine concentrations | mol/L |
| `PCO2`, `PCOS`, `PCS2` | Partial pressures of individual gas components | bar |
| `Ptot` | Total gas-phase pressure | bar |
| `cCO2`, `cCOS`, `cCS2` | Liquid-phase concentrations of free dissolved gas components | mol/L |
| `ACOOH`, `ACOSH`, `ACSSH`, `BCOOH`, `BCOSH` | Concentrations of amine–gas adduct products | mol/L |
| `AH`, `BH`, `HS`, `xCOS` | Hydrolysis-related ionic concentrations or hydrolysis progress variables, depending on the program | mol/L |
| `nCO2_gen` or `nCO2_from_COS` | Amount of CO2 generated from COS hydrolysis | mol |
| `nCOS_hyd` | Amount of COS consumed by hydrolysis | mol |
| `nCO2_abs_net` | Initial gas-phase CO2 amount minus the equilibrium gas-phase CO2 amount | mol |
| `nCOS_abs` or `nCOS_abs_net` | Initial gas-phase COS amount minus the equilibrium gas-phase COS amount | mol |
| `nCS2_abs` | Initial gas-phase CS2 amount minus the equilibrium gas-phase CS2 amount | mol |
| `ResNormScaled` | Scaled Euclidean norm of the residual vector; generally, a smaller value indicates better numerical convergence | — |
| `ResNormRaw` | Unscaled Euclidean norm of the residual vector; not suitable for direct comparison across cases because the equations may have different dimensions and scales | — |

**Note:** The meanings of `u1`, `u2`, and `u3` depend on the selected program. In particular, `u2` does not represent the same gas component in every model. Refer to the corresponding program when interpreting these variables.

## 7. Interpretation of Absorption Amounts

The programs commonly calculate the net gas-phase disappearance amount as:

`n_i,abs = n_i,0 - n_i,g`

This quantity does not necessarily represent physical dissolution alone.

When COS hydrolysis is included:

- The net decrease in gas-phase COS results from physical dissolution, adduct formation, and hydrolysis consumption.
- CO2 can be generated during COS hydrolysis.
- Consequently, `nCO2_abs_net` may become negative.

A negative net CO2 absorption amount should not automatically be interpreted as a programming error. The CO2 generated through COS hydrolysis and its effect on the gas-phase composition should first be examined.

For selectivity analysis, the definition of absorption must be consistent throughout the study.

The following quantities should not be used interchangeably:

- Net gas-phase disappearance.
- Total liquid-phase retention.
- Absorption amount corrected for reaction-generated or reaction-consumed species.

The selected definition should be clearly stated in subsequent data analysis and reporting.

## 8. Solver Status and Troubleshooting

### 8.1 Missing Excel Columns

Check the required column names, spelling, and the first worksheet of the input file.

The single-amine COS–CO2, CO2–CS2, and ternary programs use strict matching of required column names. The mixed-amine program supports aliases and case-insensitive matching.

Using the standard column names listed in Section 3 is recommended.

### 8.2 `Solved = false`

Check the following input parameters:

- `R`, `T`, `Vg`, `VL`, and `CLtot`.
- Henry's law parameters.
- Reaction equilibrium constants.
- Initial amine concentrations.
- Initial gas-phase mole fractions.

Then inspect `Exitflag`, `Tries`, `ResNormScaled`, and `ResNormRaw`.

It is recommended to test a single known calculation case before performing batch calculations.

### 8.3 Different Results Between Repeated Calculations

The programs use randomized initial guesses for the nonlinear solver and reset the random number generator during execution.

When comparing repeated calculations, examine the residuals, mass balance closure, and physical plausibility rather than relying only on a single numerical result.

### 8.4 NaN Values in the Output

NaN values may indicate that the corresponding calculation case did not converge successfully.

Filter cases with `Solved = false` and inspect their input parameters.

Do not directly replace NaN values with zero.

### 8.5 Negative Net CO2 Absorption

In models that include COS hydrolysis, CO2 can be generated by the hydrolysis reaction.

Check `nCO2_gen` or `nCO2_from_COS` and distinguish net gas-phase changes from total absorption.

### 8.6 Slow Calculations

Each calculation case may involve multiple randomized initial guesses and repeated calls to `fsolve`.

Recommended practices:

- Test a small number of cases first.
- Check the convergence behavior.
- Avoid relaxing convergence tolerances without validation.
- Perform batch calculations only after confirming the reliability of individual cases.

## 9. Important Implementation Details

1. The programs `calucatemodel.m`, `calucatemodelCO2CS2.m`, and `calucatemodelCO2COSCS2.m` use strict matching of required input column names. The mixed-amine program, `calucatemodelmix.m`, supports aliases and case-insensitive matching.

2. The mixed-amine model requires separate reaction equilibrium constants for amines A and B. Single-amine equilibrium constants should not be directly reused without verification.

3. The ternary model does not consider CS2 hydrolysis or the conversion of CS2 into COS.

4. The solver loop in the ternary model does not directly reject all solutions with `exitflag <= 0` before accepting numerical results, unlike the other programs. Therefore, `Solved`, `Exitflag`, residuals, and physical plausibility should be examined together.

5. Input validation is not fully identical across the four programs. Users should independently verify all concentrations, Henry's law parameters, reaction equilibrium constants, and gas-phase mole fractions before running the calculations.

6. `Solved = true` only indicates that the numerical solution satisfies the residual criterion specified in the program. It does not establish the validity of the model assumptions or the accuracy of the experimental data.

## 10. Recommended Workflow

**Step 1. Select the appropriate model.**

Choose the program according to the gas system being investigated.

**Step 2. Prepare the Excel input file.**

Use the required column names for the selected program and ensure that all input parameters follow a consistent unit system.

**Step 3. Test a single known calculation case.**

Start with a case for which experimental data or a previously validated result is available.

**Step 4. Examine the numerical solution.**

Check `Solved`, `Exitflag`, residuals, mass balance closure, and physical plausibility.

**Step 5. Perform batch calculations.**

Proceed with larger datasets only after confirming that the individual calculation cases are reliable.

**Step 6. Save and analyze the results.**

Retain the original Excel input file and the generated TXT and CSV outputs. Identify unconverged cases and maintain a consistent definition of absorption amount and selectivity throughout subsequent analysis.

---

**End of User Guide**
