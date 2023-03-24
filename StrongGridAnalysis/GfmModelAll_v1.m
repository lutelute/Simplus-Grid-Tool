% This function analyzes the interaction between synchronization loop,
% voltage loop, and grid impedance for GFM inverter.

% Author(s): Yitong Li

% Two different perspectives:
% 1. v-i perspective: voltage loop and grid impedance.
% 2. P-w perspective: Synchronization loop.
% For theoratical analysis:
% 1. All v-i perspective: Transform synchronization loop into virtual
% impedance, and analyze it together with voltage loop and grid impedance.
% The instability is caused by negative impedance (i.e., amplitude frame
% damping) in this case.
% 2. All P-w perspective: Transform voltage loop and grid impedance into
% synchronizing and damping power, and analyze them together with
% synchronization loop. The instability is caused by the negative damping
% torque (i.e., phase frame damping) in this case.

clear all
% close all
clc

%%
CaseVoltageControl = 'DoubleLoop';
% CaseVoltageControl = 'SingleLoop';
% CaseVoltageControl = 'OpenLoop';

CaseResistor = 'Yes';
CaseDamping = 'Yes';
CaseInertia = 'Yes';

%% Base value
BaseValue();

%% Set parameters
% Grid voltage
syms vgD vgQ wg

% Line impedance
syms Lg Rg

% LC Filter
syms Lf Cf Rf

% Droop control
syms vdr vqr wf Dw Dv Pr Qr V0 W0

% Voltage controller
syms kpv kiv

% Current controller
syms kpi kii

% Cross-decoupling gain
Fcdv = 0;
Fcdi = 0;

%% System states
% Droop controller
syms w delta

% Voltage controller
syms vdi vqi

% Current controller
syms idi iqi

% Passive component
syms id iq vd vq igd igq

%%
% Inverse frame transformation
% vgdq = vgDQ * e^{-j*delta}
vgd = vgD*cos(delta) + vgQ*sin(delta);
vgq = -vgD*sin(delta) + vgQ*cos(delta);

% Power calculation
q = vq*igd - vd*igq;
p = vd*id + vq*iq;

% Droop control
% Equations:
switch CaseDamping
    case 'Yes'          % With damping
        dw = ((Pr-p)*Dw + W0 - w)*wf;
    case 'No'           % No damping
        dw = ((Pr-p)*Dw + W0)*wf;
    otherwise
        error('Error: Error case for damping.')
end
% dvdr = ((Qr-q)*Dv + V0 - vdr)*wf;

% Angle difference between inverter and inf bus
% s*delta = w - wg;
ddelta = w - wg;
% dtheta = w;

% Inner-loop control
switch CaseVoltageControl
    
    case 'DoubleLoop'
        % ###
        % Stable: fast voltage loop, weak grid, with Rf and Rg, slow droop
        % Unstable: slow voltage loop, strong grid, without Rf and Rg, fast droop
        
        % Outer-loop voltage control
        dvdi = vdr - vd;
        dvqi = vqr - vq;
        idr = kpv*dvdi + kiv*vdi - Fcdv*Cf*Wbase*vq;
        iqr = kpv*dvqi + kiv*vqi + Fcdv*Cf*Wbase*vd;

        % Inner-loop current control
        didi = idr - id;
        diqi = iqr - iq;
        ed = kpi*didi + kii*idi - Fcdi*Lf*Wbase*iq;
        eq = kpi*diqi + kii*iqi + Fcdi*Lf*Wbase*iq;
        
    case 'SingleLoop'
        % ###
        % Stable: slow voltage loop
        % Unstable: fast voltage loop
        
        % Voltage control
        dvdi = vdr - vd;
        dvqi = vqr - vq;
        
        ed = kpv*dvdi + kiv*vdi - Fcdv*Cf*Wbase*vq;
        eq = kpv*dvqi + kiv*vqi + Fcdv*Cf*Wbase*vd;
        % eq = 0;
        
    case 'OpenLoop'
        % ###
        % Always stable
       
        % Open loop voltage control
        ed = vdr;
        eq = vqr;
        
    otherwise
        error('Error: Error case for voltage contorl.')
        
end

% Inverter-side inductor
did = (ed - vd + w*Lf*iq - Rf*id)/Lf;
diq = (eq - vq - w*Lf*id - Rf*iq)/Lf;

% Filter capacitor
dvd = (id-igd + w*Cf*vq)/Cf;
dvq = (iq-igq - w*Cf*vd)/Cf;

% Grid-side inductor
digd = (vd - vgd + w*Lg*igq - Rg*igd)/Lg;
digq = (vq - vgq - w*Lg*igd - Rg*igq)/Lg;

%% Calculate the state matrix
switch CaseVoltageControl
    case 'DoubleLoop'
        state = [vdi; vqi; idi; iqi; id; iq; vd; vq; igd; igq; delta; w];
        f_xu = [dvdi; dvqi; didi; diqi; did; diq; dvd; dvq; digd; digq; ddelta; dw];
    case 'SingleLoop'
      	state = [vdi; vqi; id; iq; vd; vq; igd; igq; delta; w];
        f_xu = [dvdi; dvqi; did; diq; dvd; dvq; digd; digq; ddelta; dw];
    case 'OpenLoop'
        state = [id; iq; vd; vq; igd; igq; delta; w];
        f_xu = [did; diq; dvd; dvq; digd; digq; ddelta; dw];
end

Amat = jacobian(f_xu,state);

%% Set numerical number
switch CaseResistor
    case 'Yes'
        RatioRX = 1/5;
    case 'No'
        RatioRX = 0;
    otherwise
        error('Error: Error case for resistor.')
end

Cf = 0.02/Wbase;
Xf = 0.05;
Lf = Xf/Wbase;
Rf = Xf*RatioRX;

switch CaseInertia
    case 'Yes';     wf = 2*pi*10;
    case 'No';      wf = 2*pi*100;
    otherwise;      error('Error: Error case for inertia.');
end

wv = 250*2*pi;
kpv = Cf*wv;
kiv = Cf*wv^2/4*20;

wi = 1000*2*pi;
kpi = Lf*wi;
kii = Lf*(wi^2)/4;

Dw = 0.05*Wbase/Sbase;
Dv = 0;

% vd = 0.707;
% vq = 0.707;
% vgD = 0.707;
% vgQ = 0.707;
vd = 1;
vq = 0;
vgD = 1;
vgQ = 0;

P = 0.5;
Q = 0;
igd = P/vd;
igq = -Q/vd;
igD = igd;
igQ = igq;
id = igd;
iq = igq;

vdr = vd;
vqr = vq;

delta = 0/180*pi;

Xg = 0.2;
Lg = Xg/Wbase;
Rg = Xg*RatioRX;



% 
Pr = P;
W0 = Wbase;
w = Wbase;
wg = Wbase;

%% Replace symbolic by numerical number

Amat = subs(Amat,'kpi',kpi);
Amat = subs(Amat,'kii',kii);

Amat = subs(Amat,'Dw',Dw);
Amat = subs(Amat,'Dv',Dv);

Amat = subs(Amat,'vd',vd);
Amat = subs(Amat,'vq',vq);
Amat = subs(Amat,'delta',delta);

Amat = subs(Amat,'igd',igd);
Amat = subs(Amat,'igq',igq);

Amat = subs(Amat,'vgD',vgD);
Amat = subs(Amat,'vgQ',vgQ);

Amat = subs(Amat,'id',id);
Amat = subs(Amat,'iq',iq);

Amat = subs(Amat,'wf',wf);
% Amat = subs(Amat,'Pr',Pr);
% Amat = subs(Amat,'W0',Wbase);

Amat = subs(Amat,'Cf',Cf);
Amat = subs(Amat,'Lf',Lf);

Amat = subs(Amat,'w',Wbase);
Amat = subs(Amat,'wg',Wbase);

Amat = subs(Amat,'Rf',Rf);

Amat = subs(Amat,'Rg',Rg);
Amat = subs(Amat,'Lg',Lg);

Amat = subs(Amat,'kpv',kpv);
Amat = subs(Amat,'kiv',kiv);


%% Sweep parameters
EigVec = eig(Amat);
EigVecHz = EigVec/(2*pi);
ZoomInAxis = [-20,10,-60,60];
PlotPoleMap(EigVecHz,ZoomInAxis,9999);

% ScaleFactor = logspace(-1,2,10);
% for i = 1:length(ScaleFactor)
% Amat_ = subs(Amat,'kiv',kiv*ScaleFactor(i));
% 
% Amat_ = double(Amat_);
% 
% % Calculate poles
% EigVec = eig(Amat_);
% EigVecHz = EigVec/(2*pi);
% 
% % Plot poles
% ZoomInAxis = [-20,10,-60,60];
% PlotPoleMap(EigVecHz,ZoomInAxis,9999);
% end