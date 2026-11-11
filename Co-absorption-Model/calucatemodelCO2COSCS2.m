%% Batch solve from Excel -> write results to text/csv
% STATIC ABSORPTION VESSEL (closed system), equilibrium only
%
% Chemistry:
%   (1) Adducts:
%       A + CO2(aq) <-> ACOOH
%       [ACOOH] = KCO2 * [A] * [CO2(aq)]
%
%       A + COS(aq) <-> ACOSH
%       [ACOSH] = KCOS * [A] * [COS(aq)]
%
%       A + CS2(aq) <-> ACSSH
%       [ACSSH] = KCS2 * [A] * [CS2(aq)]
%
%   (2) COS hydrolysis:
%       A + H2O + COS <-> AH+ + HS- + CO2
%       KhydCOS = ([AH+][HS-] * c) / (a * s)
%       let x = [AH+] = [HS-]
%       => x^2*c - KhydCOS*a*s = 0
%
% No CS2 hydrolysis is considered in this version.
% No COS generation from CS2 is considered in this version.
%
% Unknowns:
%   u1 = nCO2_g  (mol)
%   u2 = nCOS_g  (mol)
%   u3 = nCS2_g  (mol)
%   a  = [A] free amine (mol/L)
%   x  = COS hydrolysis extent (mol/L)
%
% Equations:
%   (1) Amine balance:
%       a + ACOOH + ACOSH + ACSSH + x = CA0
%
%   (2) CO2 balance:
%       u1 + VL*(c + ACOOH) = nCO2_0 + VL*x
%
%   (3) COS balance:
%       u2 + VL*(s + ACOSH + x) = nCOS_0
%
%   (4) CS2 balance:
%       u3 + VL*(d + ACSSH) = nCS2_0
%
%   (5) COS hydrolysis equilibrium:
%       x^2*c - KhydCOS*a*s = 0
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
resultTxt  = fullfile(path, 'results_static_CO2_COS_CS2_no_CS2_hydrolysis.txt');
resultCsv  = fullfile(path, 'results_static_CO2_COS_CS2_no_CS2_hydrolysis.csv');

maxTries   = 1000;
tolRes     = 1e-8;

opts = optimoptions('fsolve', ...
    'Display','off', ...
    'FunctionTolerance',1e-12, ...
    'StepTolerance',1e-12, ...
    'OptimalityTolerance',1e-12, ...
    'MaxIterations',3000, ...
    'MaxFunctionEvaluations',80000);

rng('shuffle');

%% ========= Read Excel =========
Ttbl = readtable(excelFile, 'Sheet', sheetName, 'PreserveVariableNames', true);

% ---- Required numeric parameter columns ----
% 注意：
% 本版本不需要 KhydCS2。
% KhydCOS 对应：A + H2O + COS <-> AH+ + HS- + CO2
reqNum = {'R','T','Vg','VL','CLtot','CA0','ng0', ...
          'yCO20','yCOS0','yCS20', ...
          'HCO2','HCOS','HCS2', ...
          'KCO2','KCOS','KCS2', ...
          'KhydCOS'};

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
u2 = nan(nCase,1);   % mol, nCOS_g
u3 = nan(nCase,1);   % mol, nCS2_g
a  = nan(nCase,1);   % mol/L, free amine

% Gas-phase pressures
PCO2 = nan(nCase,1);
PCOS = nan(nCase,1);
PCS2 = nan(nCase,1);
Ptot = nan(nCase,1);

% Liquid concentrations
cCO2  = nan(nCase,1);
cCOS  = nan(nCase,1);
cCS2  = nan(nCase,1);

% Adducts
ACOOH = nan(nCase,1);
ACOSH = nan(nCase,1);
ACSSH = nan(nCase,1);

% COS hydrolysis extent
xCOS  = nan(nCase,1);

AH_total = nan(nCase,1);
HS_total = nan(nCase,1);

% Initial moles
nCO2_0 = nan(nCase,1);
nCOS_0 = nan(nCase,1);
nCS2_0 = nan(nCase,1);

% Mole accounting
nCO2_from_COS = nan(nCase,1);  % CO2 generated from COS hydrolysis
nCOS_hyd      = nan(nCase,1);  % COS consumed by COS hydrolysis

nCO2_abs_net = nan(nCase,1);
nCOS_abs_net = nan(nCase,1);
nCS2_abs     = nan(nCase,1);

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

    [solved, out, stats] = solve_one_case_static_5eq_CO2_COS_CS2_no_CS2_hyd(p, maxTries, tolRes, opts);

    Solved(i)   = solved;
    Tries(i)    = stats.triesUsed;
    Exitflag(i) = stats.exitflag;
    ResNormScaled(i) = stats.bestScaledNorm;
    ResNormRaw(i)    = stats.bestRawNorm;

    nCO2_0(i) = max(0, p.ng0*p.yCO20);
    nCOS_0(i) = max(0, p.ng0*p.yCOS0);
    nCS2_0(i) = max(0, p.ng0*p.yCS20);

    if solved
        u1(i) = out.u1;
        u2(i) = out.u2;
        u3(i) = out.u3;
        a(i)  = out.a;

        PCO2(i) = out.PCO2;
        PCOS(i) = out.PCOS;
        PCS2(i) = out.PCS2;
        Ptot(i) = out.Ptot;

        cCO2(i) = out.cCO2;
        cCOS(i) = out.cCOS;
        cCS2(i) = out.cCS2;

        ACOOH(i) = out.ACOOH;
        ACOSH(i) = out.ACOSH;
        ACSSH(i) = out.ACSSH;

        xCOS(i) = out.xCOS;

        AH_total(i) = out.AH_total;
        HS_total(i) = out.HS_total;

        nCO2_from_COS(i) = out.nCO2_from_COS;
        nCOS_hyd(i)      = out.nCOS_hyd;

        nCO2_abs_net(i) = out.nCO2_abs_net;
        nCOS_abs_net(i) = out.nCOS_abs_net;
        nCS2_abs(i)     = out.nCS2_abs;
    end

    fprintf(['Case %d/%d: solvent=%s, massConc=%.6g, T=%.4g K, solved=%d, tries=%d, bestScaled=%.3e, ' ...
             'uCO2=%.3e, uCOS=%.3e, uCS2=%.3e mol, a=%.3e mol/L, ' ...
             'PCO2=%.3e, PCOS=%.3e, PCS2=%.3e, xCOS=%.3e, nCS2_abs=%.3e mol\n'], ...
        i, nCase, Solvent(i), MassConc(i), TempK(i), solved, stats.triesUsed, stats.bestScaledNorm, ...
        out.u1, out.u2, out.u3, out.a, out.PCO2, out.PCOS, out.PCS2, out.xCOS, out.nCS2_abs);
end

%% ========= Write results =========
Rout = table( ...
    CaseID, Solvent, MassConc, TempK, Solved, Tries, Exitflag, ...
    nCO2_0, nCOS_0, nCS2_0, ...
    u1, u2, u3, a, ...
    PCO2, PCOS, PCS2, Ptot, ...
    cCO2, cCOS, cCS2, ...
    ACOOH, ACOSH, ACSSH, ...
    xCOS, AH_total, HS_total, ...
    nCO2_from_COS, nCOS_hyd, ...
    nCO2_abs_net, nCOS_abs_net, nCS2_abs, ...
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

%% ========= Solver: 5 unknowns =========
function [solved, out, stats] = solve_one_case_static_5eq_CO2_COS_CS2_no_CS2_hyd(p, maxTries, tolRes, opts)

    solved = false;

    out = struct('u1',NaN,'u2',NaN,'u3',NaN,'a',NaN, ...
                 'PCO2',NaN,'PCOS',NaN,'PCS2',NaN,'Ptot',NaN, ...
                 'cCO2',NaN,'cCOS',NaN,'cCS2',NaN, ...
                 'ACOOH',NaN,'ACOSH',NaN,'ACSSH',NaN, ...
                 'xCOS',NaN,'AH_total',NaN,'HS_total',NaN, ...
                 'nCO2_from_COS',NaN,'nCOS_hyd',NaN, ...
                 'nCO2_abs_net',NaN,'nCOS_abs_net',NaN,'nCS2_abs',NaN);

    best = struct('scaledNorm',inf,'rawNorm',inf,'exitflag',-999,'out',out);

    must = [p.R,p.T,p.Vg,p.VL,p.CLtot,p.CA0,p.ng0, ...
            p.yCO20,p.yCOS0,p.yCS20, ...
            p.HCO2,p.HCOS,p.HCS2, ...
            p.KCO2,p.KCOS,p.KCS2, ...
            p.KhydCOS];

    if any(~isfinite(must)) || ...
       p.R<=0 || p.T<=0 || p.Vg<=0 || p.VL<0 || p.CLtot<=0 || p.CA0<0 || p.ng0<0 || ...
       p.HCO2<=0 || p.HCOS<=0 || p.HCS2<=0 || ...
       p.KCO2<0 || p.KCOS<0 || p.KCS2<0 || p.KhydCOS<0

        stats.triesUsed = 0;
        stats.exitflag = -999;
        stats.bestScaledNorm = inf;
        stats.bestRawNorm = inf;
        return;
    end

    nCO2_0 = max(0, p.ng0 * p.yCO20);
    nCOS_0 = max(0, p.ng0 * p.yCOS0);
    nCS2_0 = max(0, p.ng0 * p.yCS20);
    nInert_0 = max(0, p.ng0 * max(0, 1 - p.yCO20 - p.yCOS0 - p.yCS20));

    % Trivial case
    if nCO2_0==0 && nCOS_0==0 && nCS2_0==0
        out.u1 = 0;
        out.u2 = 0;
        out.u3 = 0;
        out.a  = p.CA0;

        out.PCO2 = 0;
        out.PCOS = 0;
        out.PCS2 = 0;
        out.Ptot = nInert_0 * p.R * p.T / p.Vg;

        out.cCO2 = 0;
        out.cCOS = 0;
        out.cCS2 = 0;

        out.ACOOH = 0;
        out.ACOSH = 0;
        out.ACSSH = 0;

        out.xCOS = 0;
        out.AH_total = 0;
        out.HS_total = 0;

        out.nCO2_from_COS = 0;
        out.nCOS_hyd = 0;

        out.nCO2_abs_net = 0;
        out.nCOS_abs_net = 0;
        out.nCS2_abs = 0;

        solved = true;
        stats.triesUsed = 1;
        stats.exitflag = 1;
        stats.bestScaledNorm = 0;
        stats.bestRawNorm = 0;
        return;
    end

    uMin = 1e-30;   % mol
    cMin = 1e-30;   % mol/L

    for k = 1:maxTries
        z0 = makeInitialGuess_log_uuua_x(nCO2_0, nCOS_0, nCS2_0, p.CA0, p.VL, uMin, cMin);

        G = @(z) residual5_scaled_from_z(z, p, nCO2_0, nCOS_0, nCS2_0, uMin, cMin);

        try
            [zsol, fval, exitflag] = fsolve(G, z0, opts);
        catch
            continue;
        end

        if any(~isfinite(zsol)) || any(~isfinite(fval))
            continue;
        end

        scaledNorm = norm(fval,2);

        X = exp(zsol(:));
        X(1) = max(uMin, X(1));
        X(2) = max(uMin, X(2));
        X(3) = max(uMin, X(3));
        X(4) = max(cMin, X(4));
        X(5) = max(cMin, X(5));

        raw = residual5_raw_from_x(X, p, nCO2_0, nCOS_0, nCS2_0);
        rawNorm = norm(raw,2);

        out_try = compute_outputs_from_x(X, p, nCO2_0, nCOS_0, nCS2_0, nInert_0);

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

function z0 = makeInitialGuess_log_uuua_x(nCO2_0, nCOS_0, nCS2_0, CA0, VL, uMin, cMin)

    if nCO2_0 > 0
        u1 = max(uMin, nCO2_0 * 10^(-4 + 4*rand));
    else
        u1 = uMin * 10^(0 + 6*rand);
    end

    if nCOS_0 > 0
        u2 = max(uMin, nCOS_0 * 10^(-4 + 4*rand));
    else
        u2 = uMin * 10^(0 + 6*rand);
    end

    if nCS2_0 > 0
        u3 = max(uMin, nCS2_0 * 10^(-4 + 4*rand));
    else
        u3 = uMin * 10^(0 + 6*rand);
    end

    if CA0 > 0
        a = max(cMin, CA0 * 10^(-4 + 4*rand));
    else
        a = cMin * 10^(0 + 6*rand);
    end

    if VL > 0
        xBase = max([nCOS_0/VL, 1e-6*CA0, cMin]);
    else
        xBase = max([1e-6*CA0, cMin]);
    end

    xCOS = max(cMin, xBase * 10^(-4 + 4*rand));

    z0 = log([u1; u2; u3; a; xCOS]);
end

%% ========= Scaled residuals =========
function r = residual5_scaled_from_z(z, p, nCO2_0, nCOS_0, nCS2_0, uMin, cMin)

    X = exp(z(:));
    X(1) = max(uMin, X(1));
    X(2) = max(uMin, X(2));
    X(3) = max(uMin, X(3));
    X(4) = max(cMin, X(4));
    X(5) = max(cMin, X(5));

    rraw = residual5_raw_from_x(X, p, nCO2_0, nCOS_0, nCS2_0);

    if any(~isfinite(rraw))
        r = ones(5,1)*1e6;
        return;
    end

    scaleA   = max(1e-12, p.CA0);
    scaleCO2 = max(1e-12, nCO2_0 + p.VL*p.CA0);
    scaleCOS = max(1e-12, nCOS_0 + p.VL*p.CA0);
    scaleCS2 = max(1e-12, nCS2_0 + p.VL*p.CA0);

    scaleConc = max(1e-12, p.CA0);
    scaleHyd  = max(1e-18, scaleConc^3);

    r = rraw ./ [scaleA; scaleCO2; scaleCOS; scaleCS2; scaleHyd];

    if any(~isfinite(r))
        r = ones(5,1)*1e6;
    end
end

%% ========= Raw residuals =========
function rraw = residual5_raw_from_x(X, p, nCO2_0, nCOS_0, nCS2_0)

    u1   = X(1);  % CO2 gas
    u2   = X(2);  % COS gas
    u3   = X(3);  % CS2 gas
    a    = X(4);  % free amine
    xCOS = X(5);  % COS hydrolysis extent

    PCO2 = u1 * p.R * p.T / p.Vg;
    PCOS = u2 * p.R * p.T / p.Vg;
    PCS2 = u3 * p.R * p.T / p.Vg;

    if any(~isfinite([PCO2,PCOS,PCS2])) || any([PCO2,PCOS,PCS2] < 0)
        rraw = ones(5,1)*1e30;
        return;
    end

    c = p.CLtot * PCO2 / p.HCO2;
    s = p.CLtot * PCOS / p.HCOS;
    d = p.CLtot * PCS2 / p.HCS2;

    if any(~isfinite([c,s,d])) || any([c,s,d] < 0)
        rraw = ones(5,1)*1e30;
        return;
    end

    ACOOH = p.KCO2 * a * c;
    ACOSH = p.KCOS * a * s;
    ACSSH = p.KCS2 * a * d;

    if any(~isfinite([ACOOH,ACOSH,ACSSH])) || any([ACOOH,ACOSH,ACSSH] < 0)
        rraw = ones(5,1)*1e30;
        return;
    end

    rraw = zeros(5,1);

    % (1) Amine balance
    rraw(1) = a + ACOOH + ACOSH + ACSSH + xCOS - p.CA0;

    % (2) CO2 balance
    % CO2 is generated only from COS hydrolysis.
    rraw(2) = u1 + p.VL*(c + ACOOH) - (nCO2_0 + p.VL*xCOS);

    % (3) COS balance
    % COS is consumed by adduct formation and COS hydrolysis.
    % No COS is generated from CS2 in this version.
    rraw(3) = u2 + p.VL*(s + ACOSH + xCOS) - nCOS_0;

    % (4) CS2 balance
    % CS2 is consumed only by physical dissolution and adduct formation.
    rraw(4) = u3 + p.VL*(d + ACSSH) - nCS2_0;

    % (5) COS hydrolysis equilibrium
    if p.KhydCOS == 0
        rraw(5) = xCOS;
    else
        rraw(5) = xCOS^2 * c - p.KhydCOS * a * s;
    end
end

function out = compute_outputs_from_x(X, p, nCO2_0, nCOS_0, nCS2_0, nInert_0)

    u1   = X(1);
    u2   = X(2);
    u3   = X(3);
    a    = X(4);
    xCOS = X(5);

    PCO2 = u1 * p.R * p.T / p.Vg;
    PCOS = u2 * p.R * p.T / p.Vg;
    PCS2 = u3 * p.R * p.T / p.Vg;

    c = p.CLtot * PCO2 / p.HCO2;
    s = p.CLtot * PCOS / p.HCOS;
    d = p.CLtot * PCS2 / p.HCS2;

    ACOOH = p.KCO2 * a * c;
    ACOSH = p.KCOS * a * s;
    ACSSH = p.KCS2 * a * d;

    out.u1 = u1;
    out.u2 = u2;
    out.u3 = u3;
    out.a  = a;

    out.PCO2 = PCO2;
    out.PCOS = PCOS;
    out.PCS2 = PCS2;

    ntot_g = nInert_0 + u1 + u2 + u3;
    out.Ptot = ntot_g * p.R * p.T / p.Vg;

    out.cCO2 = c;
    out.cCOS = s;
    out.cCS2 = d;

    out.ACOOH = ACOOH;
    out.ACOSH = ACOSH;
    out.ACSSH = ACSSH;

    out.xCOS = xCOS;

    out.AH_total = xCOS;
    out.HS_total = xCOS;

    out.nCO2_from_COS = p.VL * xCOS;
    out.nCOS_hyd      = p.VL * xCOS;

    out.nCO2_abs_net = nCO2_0 - u1;
    out.nCOS_abs_net = nCOS_0 - u2;
    out.nCS2_abs     = nCS2_0 - u3;
end