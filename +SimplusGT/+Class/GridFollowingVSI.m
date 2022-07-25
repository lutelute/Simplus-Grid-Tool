% This class defines the model of grid-following VSI

% Author(s): Yitong Li, Yunjie Gu

%% Notes
%
% The model is in 
% ac-side: load convention, admittance form.
% dc-side: source convention, impedance form.

%% Class

classdef GridFollowingVSI < SimplusGT.Class.ModelAdvance
    
    % For temporary use
    properties(Access = protected)
        i_q_r;
    end 
    
    methods
        % constructor
        function obj = GridFollowingVSI(varargin)
            % Support name-value pair arguments when constructing object
            setProperties(obj,nargin,varargin{:});
        end
    end

    methods(Static)
        
        function [State,Input,Output] = SignalList(obj)
          	% Notes:
            % P_dc is the output power to dc side.
            % The "_i" in "i_d_i", "i_q_i", "v_dc_i" means integral. These
            % states appear because PI controllers are used
            % correspondingly.
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                State = {'i_d','i_q','i_d_i','i_q_i','v_od','v_oq','i_od','i_oq','w_pll_i','w','theta','v_dc','v_dc_i'};
            elseif obj.ApparatusType == 11
                State = {'i_d','i_q','i_d_i','i_q_i','v_od','v_oq','i_od','i_oq','w_pll_i','w','theta'};
            elseif obj.ApparatusType == 13
                State = {'i_ld','i_lq','i_ld_i','i_lq_i','v_od','v_oq','i_od','i_oq','w_pll_i','w','theta'};
            else
                error('Error: Invalid ApparatusType.');
            end
        	Input = {'v_d','v_q','ang_r','P_dc'};
            Output = {'i_d','i_q','w','v_dc','theta'};
        end
        
        function [x_e,u_e,xi] = Equilibrium(obj)
            % Get the power PowerFlow values
            P 	= obj.PowerFlow(1);
            Q	= obj.PowerFlow(2);
            V	= obj.PowerFlow(3);
            xi	= obj.PowerFlow(4);
            w   = obj.PowerFlow(5);

            % Get parameters
            V_dc = obj.Para(2);
            wLf  = obj.Para(7);
            R    = obj.Para(8);
            W0   = obj.Para(9);
            Lf   = wLf/W0;

            % Calculate paramters
            i_d = P/V;
            i_q = -Q/V;     % Because of conjugate "i"
            v_d = V;
            v_q = 0;
            i_dq = i_d + 1j*i_q;
            v_dq = v_d + 1j*v_q;
            e_dq = v_dq - i_dq * (R + 1j*Lf*w);
            e_d = real(e_dq);
            e_q = imag(e_dq);
            i_d_i = e_d;
            i_q_i = e_q;
            i_d_r = i_d;
            i_q_r = i_q;
            w_pll_i = w;
            v_dc_i = i_d;
            v_dc = V_dc;
            P_dc = e_d*i_d + e_q*i_q;
            ang_r = 0;
            theta = xi;
            
            v_od = v_d;
            v_oq = v_q;
            i_od = i_d;
            i_oq = i_q;
            
            % ??? Temp
            obj.i_q_r = i_q_r;

            % Get equilibrium
            x_e_1 = [i_d; i_q; i_d_i; i_q_i; v_od; v_oq; i_od; i_oq; w_pll_i; w; theta];
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                x_e = [x_e_1; v_dc; v_dc_i];
            elseif obj.ApparatusType == 11
                x_e = x_e_1;
            elseif obj.ApparatusType == 13
                x_e = [i_d; i_q; i_d_i; i_q_i; v_od; v_oq; i_od; i_oq; w_pll_i; w; theta];
            else
                error('Error: Invalid ApparatusType.');
            end
        	u_e = [v_d; v_q; ang_r; P_dc];
        end

        function [Output] = StateSpaceEqu(obj,x,u,CallFlag)
            % Get the power PowerFlow values
            P0 	= obj.PowerFlow(1);
            Q0	= obj.PowerFlow(2);
            V0	= obj.PowerFlow(3);
            xi	= obj.PowerFlow(4);
            w0  = obj.PowerFlow(5);
            
           	% Get parameters
            C_dc        = obj.Para(1);
            v_dc_r      = obj.Para(2);
            f_v_dc      = obj.Para(3);
            f_pll       = obj.Para(4);     
            f_tau_pll   = obj.Para(5);
            f_i_dq      = obj.Para(6); 
            wLf         = obj.Para(7);
            R           = obj.Para(8);
            W0          = obj.Para(9);
            
            % Filter inductor
            Lf = wLf/W0;
            
            % Dc link controller parameter
            w_vdc   = f_v_dc*2*pi;
            kp_v_dc	= v_dc_r*C_dc*w_vdc;
            ki_v_dc	= kp_v_dc*w_vdc/4;
            
            % PLL controller parameter
            w_pll     = f_pll*2*pi;
            kp_pll    = w_pll;
            ki_pll    = kp_pll * w_pll/4;
            w_tau_pll = f_tau_pll*2*pi;
            tau_pll   = 1/w_tau_pll;
            
            % Current controller paramter
            w_i_dq  = f_i_dq*2*pi;
            kp_i_dq = Lf * w_i_dq;
            ki_i_dq = Lf * w_i_dq^2 /4;
            
            % Notes:
            % kp = w*L, ki = w^2*L/4. These values can ensure the current
            % loop is approximately a critically damped second order system
            % with a bandwidth w. Other PI controllers can be designed
            % similarly.
            
            % Get states
          	i_ld   	= x(1);
         	i_lq   	= x(2);
          	i_ld_i  = x(3);
            i_lq_i 	= x(4);
          	v_od = x(5);
         	v_oq = x(6);
         	i_od = x(7);
          	i_oq = x(8);
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
               	w_pll_i = x(9);
                w       = x(10);
                theta   = x(11);
                v_dc  	= x(12);
                v_dc_i 	= x(13);
            elseif obj.ApparatusType == 11
                w_pll_i = x(9);
                w       = x(10);
                theta   = x(11);
                v_dc    = v_dc_r;
                v_dc_i  = 0;
            elseif obj.ApparatusType == 13
              	w_pll_i = x(9);
                w       = x(10);
                theta   = x(11);
            	v_dc    = v_dc_r;
                v_dc_i  = 0;
            else
                error('Error: Invalid ApparatusType.');
            end

            % Get input
        	v_d    = u(1);
            v_q    = u(2);
            ang_r  = u(3);
            P_dc   = u(4);
            
            % Saturation setting
            EnableSaturation = 0;
            
%             % Frequency limit and saturation
%             w_limit_H = W0*1.1;
%             w_limit_L = W0*0.9;
%             % Current reference limit
%             i_d_limit = 1.5;
%             i_q_limit = 1.5;
%             % Ac voltage limit
%             e_d_limit_H = 1.5;
%             e_d_limit_L = -1.5;
%             e_q_limit_H = 1.5;
%             e_q_limit_L = -1.5;
            
            % Get current reference
            if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                % DC-link control
                i_d_r = (v_dc_r - v_dc)*kp_v_dc + v_dc_i;
            elseif (obj.ApparatusType == 11) || (obj.ApparatusType == 13)
                % % Active power control                                           
                i_d_r = P0/V0;
            else
               error('Invalid ApparatusType.');
            end
            % i_q_r = i_d_r * -k_pf;  % Constant pf control, PQ node in power flow
            i_q_r = obj.i_q_r;    % Constant iq control, PQ/PV node in power flow

%             % Current saturation
%             if EnableSaturation
%                 i_d_r = min(i_d_r,i_d_limit);
%                 i_d_r = max(i_d_r,-i_d_limit);
%                 i_q_r = min(i_q_r,i_q_limit);
%                 i_q_r = max(i_q_r,-i_q_limit);
%             end

            % PLL angle measurement
            % Notes:
            % "- ang_r" gives the reference in load convention, like
            % the Tw port.
            switch 2                                                                    % ?????? 
                case 1                                  % theta-PLL
                    e_ang = atan2(v_q,v_d) - ang_r;
                case 2                                  % vq-PLL
                    e_ang = v_q - ang_r;
                    if obj.ApparatusType == 13
                        e_ang = v_oq - ang_r;
                    end
                case 3                                  % Q-PLL
                    S = (v_d+1i*v_q)*conj(i_d_r+1i*i_q_r);
                    Q = imag(S);
                    % Notes:
                    % S should be calculated by removing the effects of
                    % both PIi and Lf. Hence, we use i_dq_r here based on
                    % the impedance circuit model.
                    if i_ld<=0
                        e_ang = - (Q-Q0) - ang_r;
                    else
                        e_ang = (Q-Q0) - ang_r;
                    end
                    e_ang = e_ang/abs(P0);
                    % Notes:
                   	%
                    % Noting that Q is proportional to v_q*i_d, this means
                    % the direction of active power influences the sign of
                    % Q or equivalently the PI controller in the PLL. In
                    % order to make sure case 3 is equivalent to case 1 or
                    % 2, the controller for case 3 is dependent the power
                    % flow direction.
                    %
                    % Noting that PLL is a PI controller, so that control
                    % target should be (Q-Q0) rather than Q, for reaching
                    % the required equilibria.
                    %
                    % e_ang should be scaled by i_d as well, to ensure the
                    % actual bandwidth of the PLL is right. We scale it by
                    % P for the sake of brevity.
                otherwise
                    error(['Error']);
            end

            % PLL Integral controller 
            dw_pll_i = e_ang*ki_pll;                          
%             % Anti wind-up for PLL control 
%             if EnableSaturation
%                  if (w_pll_i >= w_limit_H && dw_pll_i >=0 )|| (w_pll_i <= w_limit_L && dw_pll_i <=0 )
%                       dw_pll_i = 0;
%                  end
%             end 
            
            
            if 1                                                                          
                dw = (w_pll_i + e_ang*kp_pll - w)/tau_pll;  	% LPF
                % Notes:
                % This introduces an additional state w.
                
%                 % Limitation for w
%                 if EnableSaturation
%                      if (w >= w_limit_H && dw >=0 ) || (w <= w_limit_L && dw <= 0 )
%                         dw = 0;                  %PLL Integral controller
%                      end
%                 end 
            else
                dw = 0;                                         % No LPF
                w = w_pll_i + e_ang*kp_pll;
                % Limitation for w
                if EnableSaturation
                    w = min(w,w_limit_H);
                    w = max(w,w_limit_L);
                end  
            end
            
            dtheta = w;
            
            
            % Ac current control
            if 1                                                                        
                % dq-frame PI
                di_ld_i = -(i_d_r - i_ld)*ki_i_dq;
                di_lq_i = -(i_q_r - i_lq)*ki_i_dq;
            end
%             % Current controller anti-windup
%             if EnableSaturation
%                  if (i_ld_i >= e_d_limit_H && di_ld_i >=0 ) || (i_ld_i <= e_d_limit_L && di_ld_i <= 0)
%                     di_ld_i = 0;                  
%                  end
%                  if (i_lq_i >= e_q_limit_H && di_lq_i >= 0 ) || (i_lq_i <= e_q_limit_L && di_lq_i <= 0)
%                     di_lq_i = 0;                  
%                  end                    
%             end
            
            % Notes:
            % For dq-frame PI controller,
            % e_dq = -(i_dq_r - i_dq)*(kp + ki/s)
            % For alpha/beta-frame PR controller,
            % e_dq = -(i_dq_r - i_dq)*(kp + ki/(s+j*w-j*w0))
            % where w0 is the resonant frequency.

            % Ac voltage (duty cycle*v_dc)
            e_d = -(i_d_r - i_ld)*kp_i_dq + i_ld_i;
            e_q = -(i_q_r - i_lq)*kp_i_dq + i_lq_i;

%             % Ac voltage (duty cycle) saturation
%             if EnableSaturation
%                 e_d = min(e_d,e_d_limit_H);
%                 e_d = max(e_d,e_d_limit_L);
%                 e_q = min(e_q,e_q_limit_H);
%                 e_q = max(e_q,e_q_limit_L);
%             end
            
            % Dc link control
          	if obj.ApparatusType == 10
                dv_dc = (e_d*i_ld + e_q*i_lq - P_dc)/v_dc/C_dc;       % C_dc
                dv_dc_i = (v_dc_r - v_dc)*ki_v_dc;                  % v_dc I
%                 if EnableSaturation
%                     % Anti wind-up for vdc control
%                     if (v_dc_i >= i_d_limit && dv_dc_i >= 0 )|| (v_dc_i <= -i_d_limit && dv_dc_i <= 0 )
%                         dv_dc_i = 0;  
%                     end
%                 end         
            elseif obj.ApparatusType == 12
                i_dc = P_dc/v_dc_r;
                dv_dc = ((e_d*i_ld + e_q*i_lq)/v_dc - i_dc)/C_dc; 	% C_dc
                dv_dc_i = (v_dc_r - v_dc)*ki_v_dc;                  % v_dc I
%                 if EnableSaturation
%                     % Anti wind-up for vdc control
%                     if (v_dc_i >= i_d_limit && dv_dc_i >= 0 )|| (v_dc_i <= -i_d_limit && dv_dc_i <= 0 )
%                         dv_dc_i = 0;
%                     end
%                 end   
            elseif (obj.ApparatusType == 11) || (obj.ApparatusType == 13)
                % No dc link control
            else
                error('Invalid ApparatusType.');
            end
            
            % Ac filter inductor
          	di_ld = (v_od - R*i_ld + w*Lf*i_lq - e_d)/Lf;
            di_lq = (v_oq - R*i_lq - w*Lf*i_ld - e_q)/Lf;
            
            % Cf equation
        	% -(i_ld - i_od) = Cf*dv_cd/dt - w*Cf*v_cq
         	% -(i_lq - i_oq) = Cf*dv_cq/dt + w*Cf*v_cd
            Cf = 0.02/W0;
            dv_od = (-(i_ld - i_od) + w*Cf*v_oq)/Cf;
            dv_oq = (-(i_lq - i_oq) - w*Cf*v_od)/Cf;

         	% Lc equation
         	% v_od - v_d = -(Lc*di_od/dt + Rc*i_od - w*Lc*i_oq)
        	% v_oq - v_q = -(Lc*di_oq/dt + Rc*i_oq + w*Lc*i_od)
            Lc = 0.01/W0;
            Rc = 0.01/10;
         	di_od = (v_d - v_od - Rc*i_od + w*Lc*i_oq)/Lc;
         	di_oq = (v_q - v_oq - Rc*i_oq - w*Lc*i_od)/Lc;
            
            % State space equations
            % dx/dt = f(x,u)
            % y     = g(x,u)
            if CallFlag == 1    
            % ### Call state equation: dx/dt = f(x,u)
                f_xu_1 = [di_ld; di_lq; di_ld_i; di_lq_i; dv_od; dv_oq; di_od; di_oq; dw_pll_i; dw; dtheta];
                if (obj.ApparatusType == 10) || (obj.ApparatusType == 12)
                    f_xu = [f_xu_1; dv_dc; dv_dc_i];
                elseif obj.ApparatusType == 11
                    f_xu = f_xu_1;
                elseif obj.ApparatusType == 13
                    f_xu = [di_ld; di_lq; di_ld_i; di_lq_i; dv_od; dv_oq; di_od; di_oq; dw_pll_i; dw; dtheta];
                else
                    error('Invalid ApparatusType.');
                end
                Output = f_xu;
                
            elseif CallFlag == 2
          	% ### Call output equation: y = g(x,u)
                g_xu = [i_od; i_oq; w; v_dc; theta];
                Output = g_xu;
            end
        end

    end

end     % End class definition