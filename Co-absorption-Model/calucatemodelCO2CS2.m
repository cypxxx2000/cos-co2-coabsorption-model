%% Batch solve from Excel -> write results to text/csv
% STATIC ABSORPTION VESSEL (closed system), equilibrium only
%
% Chemistry:
%   (1) CO2 adduct:
%       A + CO2(aq) <-> ACOOH
%       [ACOOH] = KCO2 * [A] * [CO2(aq)]
%
%   (2) CS2 adduct:
%       A + CS2(aq) <-> ACSSH
%       [ACSSH] = KCS2 * [A] * [CS2(aq)]
%
% No CS2 hydrolysis is considered in this version.
% No COS generation is considered in this version.
%
% Unknowns:
%   u1 = nCO2_g  (mol)
%   u2 = nCS2_g  (mol)
%   a  = [A] free amine (mol/L)
%
% Equations:
%   (1) Amine balance:
%       a + ACOOH + ACSSH = CA0
%
%   (2) CO2 balance:
%       u1 + VL*(c + ACOOH) = nCO2_0
%
%   (3) CS2 balance:
%       u2 + VL*(d + ACSSH) = nCS2_0
%
% Henry form:
%   P = u*R*T/Vg
%   concentration = CLtot*P/H

clear; clc;

%% ========= Choose Excel file =========
[file, path] = uigetfile({'*.xlsx;*.xls','Excel Files (*.xlsx, *.xls)'}, ...
                         'Select parameter Excel file');
if isequal(file,0)
    error('No Excel file selected.');
end
excelFile = fullfile(path, file);

sheetName  = 1;
resultTxt  = fullfile(path, 'results_static_CO2_CS2_adduct_only.txt');
resultCsv  = fullfile(path, 'results_static_CO2_CS2_adduct_only.csv');

maxTries   = 500;
tolRes     = 1e-10;

opts = optimoptions('fsolve', ...
    'Display','off', ...
    'FunctionTolerance',1e-14, ...
    'StepTolerance',1e-14, ...
    'OptimalityTolerance',1e-14, ...
    'MaxIterations',2500, ...
    'MaxFunctionEvaluations',40000);

rng('shuffle');

%% ========= Read Excel =========
Ttbl = readtable(excelFile, 'Sheet', sheetName, 'PreserveVariableNames', true);

% ---- Required numeric parameter columns ----
% 本版本不需要 HCOS、KhydCS2、yCOS0
reqNum = {'R','T','Vg','VL','CLtot','CA0','ng0', ...
          'yCO20','yCS20', ...
          'HCO2','HCS2', ...
          'KCO2','KCS2'};

missingNum = setdiff(reqNum, Ttbl.Properties.VariableNames);
if ~isempty(missingNum)
    error('Excel缺少这些数值列名：%s', strjoin(missingNum, ', '));
end

% ---- Optional columns: Solvent + MassConc ----
solventCol = resolve_col(Ttbl.Properties.VariableNames, {'Solvent','solvent','溶剂分子','溶剂'});
massCol    = resolve_col(Ttbl.Properties.VariableNames, {'MassConc','massconc','mass_conc','质量浓度','浓度'});

nCase = height(Ttbl);
fprintf('Excel: %s\nTotal cases: %d\n', excelFile, nCase);

%% ========= Prepare output arrays =========
CaseID   = (1:nCase).';

Solvent  = strings(nCase,1);
MassConc = nan(nCase,1);
TempK    = nan(nCase,1);

Solved   = false(nCase,1);
Tries    = nan(nCase,1);
Exitflag = nan(nCase,1);

% Unknowns
u1 = nan(nCase,1);   % mol, nCO2_g
u2 = nan(nCase,1);   % mol, nCS2_g
a  = nan(nCase,1);   % mol/L, free amine

% Gas-phase pressures
PCO2 = nan(nCase,1);
PCS2 = nan(nCase,1);
Ptot = nan(nCase,1);

% Liquid concentrations
cCO2 = nan(nCase,1);  % free CO2(aq)
cCS2 = nan(nCase,1);  % free CS2(aq)

% Adducts
ACOOH = nan(nCase,1);
ACSSH = nan(nCase,1);

% Initial moles
nCO2_0 = nan(nCase,1);
nCS2_0 = nan(nCase,1);

% Absorption amounts
nCO2_abs_net = nan(nCase,1);  % nCO2_0 - u1
nCS2_abs     = nan(nCase,1);  % nCS2_0 - u2

ResNormScaled = nan(nCase,1);
ResNormRaw    = nan(nCase,1);

%% ========= Loop over cases =========
for i = 1:nCase
    if ~isempty(solventCol)
        Solvent(i) = to_string(Ttbl.(solventCol)(i));
    else
        Solvent(i) = "";
    end

    if ~isempty(massCol)
        MassConc(i) = to_double(Ttbl.(massCol)(i));
    else
        MassConc(i) = NaN;
    end

    TempK(i) = to_double(Ttbl.('T')(i));

    % Build parameter struct
    p = struct();
    for kf = 1:numel(reqNum)
        key = reqNum{kf};
        p.(key) = to_double(Ttbl.(key)(i));
    end

    p.Solvent  = Solvent(i);
    p.MassConc = MassConc(i);

    [solved, out, stats] = solve_one_case_static_3eq_CO2_CS2_adduct_only(p, maxTries, tolRes, opts);

    Solved(i)   = solved;
    Tries(i)    = stats.triesUsed;
    Exitflag(i) = stats.exitflag;
    ResNormScaled(i) = stats.bestScaledNorm;
    ResNormRaw(i)    = stats.bestRawNorm;

    nCO2_0(i) = max(0, p.ng0*p.yCO20);
    nCS2_0(i) = max(0, p.ng0*p.yCS20);

    if solved
        u1(i) = out.u1;
        u2(i) = out.u2;
        a(i)  = out.a;

        PCO2(i) = out.PCO2;
        PCS2(i) = out.PCS2;
        Ptot(i) = out.Ptot;

        cCO2(i) = out.cCO2;
        cCS2(i) = out.cCS2;

        ACOOH(i) = out.ACOOH;
        ACSSH(i) = out.ACSSH;

        nCO2_abs_net(i) = out.nCO2_abs_net;
        nCS2_abs(i)     = out.nCS2_abs;
    end

    fprintf(['Case %d/%d: solvent=%s, massConc=%.6g, T=%.4g K, solved=%d, tries=%d, bestScaled=%.3e, ' ...
             'uCO2=%.3e mol, uCS2=%.3e mol, a=%.3e mol/L, ' ...
             'PCO2=%.3e bar, PCS2=%.3e bar, nCS2_abs=%.3e mol\n'], ...
        i, nCase, Solvent(i), MassConc(i), TempK(i), solved, stats.triesUsed, stats.bestScaledNorm, ...
        out.u1, out.u2, out.a, out.PCO2, out.PCS2, out.nCS2_abs);
end

%% ========= Write results =========
Rout = table( ...
    CaseID, Solvent, MassConc, TempK, Solved, Tries, Exitflag, ...
    nCO2_0, nCS2_0, ...
    u1, u2, a, ...
    PCO2, PCS2, Ptot, ...
    cCO2, cCS2, ...
    ACOOH, ACSSH, ...
    nCO2_abs_net, nCS2_abs, ...
    ResNormScaled, ResNormRaw);

Rout.Properties.VariableNames{'TempK'} = 'Temperature_K';

writetable(Rout, resultTxt, 'Delimiter','\t');
writetable(Rout, resultCsv);

fprintf('\nDone. Results written to:\n  %s\n  %s\n', resultTxt, resultCsv);

%% ================= Local functions =================

function col = resolve_col(varNames, aliases)
    col = '';
    lowerNames = lower(string(varNames));
    for k = 1:numel(aliases)
        target = lower(string(aliases{k}));
        idx = find(lowerNames == target, 1);
        if ~isempty(idx)
            col = varNames{idx};
            return;
        end
    end
end

function s = to_string(v)
    if isstring(v)
        s = v;
    elseif ischar(v)
        s = string(v);
    elseif iscell(v)
        if isempty(v)
            s = "";
        else
            s = string(v{1});
        end
    else
        s = string(v);
    end

    if strlength(s) == 0
        s = "";
    end
end

function x = to_double(v)
    if isnumeric(v)
        x = v;
        return;
    end

    if iscell(v)
        if isempty(v)
            x = NaN;
            return;
        end
        v = v{1};
    end

    if isstring(v) || ischar(v)
        x = str2double(v);
    else
        x = double(v);
    end
end

%% ========= Solver: 3 unknowns (uCO2, uCS2, a), 3 equations =========
function [solved, out, stats] = solve_one_case_static_3eq_CO2_CS2_adduct_only(p, maxTries, tolRes, opts)

    solved = false;

    out = struct('u1',NaN,'u2',NaN,'a',NaN, ...
                 'PCO2',NaN,'PCS2',NaN,'Ptot',NaN, ...
                 'cCO2',NaN,'cCS2',NaN, ...
                 'ACOOH',NaN,'ACSSH',NaN, ...
                 'nCO2_abs_net',NaN,'nCS2_abs',NaN);

    best = struct('scaledNorm',inf,'rawNorm',inf,'exitflag',-999,'out',out);

    must = [p.R,p.T,p.Vg,p.VL,p.CLtot,p.CA0,p.ng0, ...
            p.yCO20,p.yCS20, ...
            p.HCO2,p.HCS2, ...
            p.KCO2,p.KCS2];

    if any(~isfinite(must)) || ...
       p.R<=0 || p.T<=0 || p.Vg<=0 || p.VL<0 || ...
       p.CLtot<=0 || p.CA0<0 || p.ng0<0 || ...
       p.HCO2<=0 || p.HCS2<=0 || ...
       p.KCO2<0 || p.KCS2<0

        stats.triesUsed = 0;
        stats.exitflag = -999;
        stats.bestScaledNorm = inf;
        stats.bestRawNorm = inf;
        return;
    end

    nCO2_0 = max(0, p.ng0 * p.yCO20);
    nCS2_0 = max(0, p.ng0 * p.yCS20);
    nInert_0 = max(0, p.ng0 * max(0, 1 - p.yCO20 - p.yCS20));

    % Trivial case
    if nCO2_0==0 && nCS2_0==0
        out.u1 = 0;
        out.u2 = 0;
        out.a  = p.CA0;

        out.PCO2 = 0;
        out.PCS2 = 0;
        out.Ptot = nInert_0 * p.R * p.T / p.Vg;

        out.cCO2 = 0;
        out.cCS2 = 0;

        out.ACOOH = 0;
        out.ACSSH = 0;

        out.nCO2_abs_net = 0;
        out.nCS2_abs = 0;

        solved = true;
        stats.triesUsed = 1;
        stats.exitflag = 1;
        stats.bestScaledNorm = 0;
        stats.bestRawNorm = 0;
        return;
    end

    uMin = 1e-30;   % mol
    aMin = 1e-30;   % mol/L

    for k = 1:maxTries
        z0 = makeInitialGuess_log_uua(nCO2_0, nCS2_0, p.CA0, uMin, aMin);

        G = @(z) residual3_scaled_from_z(z, p, nCO2_0, nCS2_0, uMin, aMin);

        try
            [zsol, fval, exitflag] = fsolve(G, z0, opts);
        catch
            continue;
        end

        if exitflag <= 0 || any(~isfinite(zsol)) || any(~isfinite(fval))
            continue;
        end

        scaledNorm = norm(fval,2);

        x = exp(zsol(:));
        x(1) = max(uMin, x(1));
        x(2) = max(uMin, x(2));
        x(3) = max(aMin, x(3));

        raw = residual3_raw_from_x(x, p, nCO2_0, nCS2_0);
        rawNorm = norm(raw,2);

        out_try = compute_outputs_from_x(x, p, nCO2_0, nCS2_0, nInert_0);

        if scaledNorm < best.scaledNorm
            best.scaledNorm = scaledNorm;
            best.rawNorm = rawNorm;
            best.exitflag = exitflag;
            best.out = out_try;
        end

        if scaledNorm < tolRes
            solved = true;
            break;
        end
    end

    out = best.out;

    stats.triesUsed = min(maxTries, k);
    stats.exitflag = best.exitflag;
    stats.bestScaledNorm = best.scaledNorm;
    stats.bestRawNorm = best.rawNorm;
end

function z0 = makeInitialGuess_log_uua(nCO2_0, nCS2_0, CA0, uMin, aMin)

    if nCO2_0 > 0
        u1 = max(uMin, nCO2_0 * 10^(-6 + 6*rand));
    else
        u1 = uMin * 10^(0 + 6*rand);
    end

    if nCS2_0 > 0
        u2 = max(uMin, nCS2_0 * 10^(-6 + 6*rand));
    else
        u2 = uMin * 10^(0 + 6*rand);
    end

    if CA0 > 0
        a = max(aMin, CA0 * 10^(-6 + 6*rand));
    else
        a = aMin * 10^(0 + 6*rand);
    end

    z0 = log([u1; u2; a]);
end

%% ========= Scaled residuals =========
function r = residual3_scaled_from_z(z, p, nCO2_0, nCS2_0, uMin, aMin)

    x = exp(z(:));
    x(1) = max(uMin, x(1));
    x(2) = max(uMin, x(2));
    x(3) = max(aMin, x(3));

    rraw = residual3_raw_from_x(x, p, nCO2_0, nCS2_0);

    if any(~isfinite(rraw))
        r = ones(3,1)*1e6;
        return;
    end

    scaleA   = max(1, p.CA0);
    scaleCO2 = max(1, nCO2_0 + p.VL*p.CA0);
    scaleCS2 = max(1, nCS2_0 + p.VL*p.CA0);

    r = rraw ./ [scaleA; scaleCO2; scaleCS2];

    if any(~isfinite(r))
        r = ones(3,1)*1e6;
    end
end

%% ========= Raw residuals: [amine, CO2, CS2] =========
function rraw = residual3_raw_from_x(x, p, nCO2_0, nCS2_0)

    u1 = x(1);  % CO2 gas
    u2 = x(2);  % CS2 gas
    a  = x(3);  % free amine

    PCO2 = u1 * p.R * p.T / p.Vg;
    PCS2 = u2 * p.R * p.T / p.Vg;

    if any(~isfinite([PCO2,PCS2])) || any([PCO2,PCS2] < 0)
        rraw = ones(3,1)*1e30;
        return;
    end

    c = p.CLtot * PCO2 / p.HCO2;
    d = p.CLtot * PCS2 / p.HCS2;

    if any(~isfinite([c,d])) || any([c,d] < 0)
        rraw = ones(3,1)*1e30;
        return;
    end

    ACOOH = p.KCO2 * a * c;
    ACSSH = p.KCS2 * a * d;

    if any(~isfinite([ACOOH,ACSSH])) || any([ACOOH,ACSSH] < 0)
        rraw = ones(3,1)*1e30;
        return;
    end

    rraw = zeros(3,1);

    % (1) Amine balance
    rraw(1) = a + ACOOH + ACSSH - p.CA0;

    % (2) CO2 balance
    rraw(2) = u1 + p.VL*(c + ACOOH) - nCO2_0;

    % (3) CS2 balance
    rraw(3) = u2 + p.VL*(d + ACSSH) - nCS2_0;
end

function out = compute_outputs_from_x(x, p, nCO2_0, nCS2_0, nInert_0)

    u1 = x(1);
    u2 = x(2);
    a  = x(3);

    PCO2 = u1 * p.R * p.T / p.Vg;
    PCS2 = u2 * p.R * p.T / p.Vg;

    c = p.CLtot * PCO2 / p.HCO2;
    d = p.CLtot * PCS2 / p.HCS2;

    ACOOH = p.KCO2 * a * c;
    ACSSH = p.KCS2 * a * d;

    out.u1 = u1;
    out.u2 = u2;
    out.a  = a;

    out.PCO2 = PCO2;
    out.PCS2 = PCS2;

    ntot_g = nInert_0 + u1 + u2;
    out.Ptot = ntot_g * p.R * p.T / p.Vg;

    out.cCO2 = c;
    out.cCS2 = d;

    out.ACOOH = ACOOH;
    out.ACSSH = ACSSH;

    out.nCO2_abs_net = nCO2_0 - u1;
    out.nCS2_abs     = nCS2_0 - u2;
end