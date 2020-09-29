% This class defines advanced properties and methods for state space models
% used in script and simulink.

% Author(s): Yitong Li, Yunjie Gu

%% Notes
%
% This class makes the model fit in both simulation (simulink) and
% theoratical analysis (script).
%
% Subclass of this class contains the specific models of different devices.
% The models should satisfy these conditions:
% - First two inputs are "v_d" and "v_q"
% - First two outputs are "i_d" and "i_q"
% - Second output is "w"
% - Final state is "theta"
% - The final state "theta" SHOULD NOT appear in other state equations
%
% Available device type:
% 00:   Synchronous generator (SG)
% 10:   PLL-controlled voltage source inverter (VSI)
% 20:   Droop-controlled voltage source inverter (VSI)
% 90:   Single-phase inductor, for test


%% Class

classdef Class_Model_Advance < Class_Model_Linearization ...
                             & matlab.system.mixin.Nondirect ...
                             & matlab.system.mixin.Propagates
   
%%
% =================================================
% Properties
% =================================================
% ### Public properties
properties
    DeviceType = [];  	% Device type
    Para = [];          % Device parameters
    PowerFlow = [];     % Power flow parameters
    Ts = [];            % Sampling period (s)
    x0 = [];            % Initial state
end

% ### Discrete state
% CAN be modefied by methods
% MUST be numeric or logical variables or fi objects (not string)
% CAN NOT be set with default values
% MUST be initialized before doing simulation
properties(DiscreteState)
    % Notes: It is better to put only x here, and put other states (such as
    % x[k+1], x[k-1], u[k+1]) to other types of properties, because the
    % size of states characteristics are also defined below.
    x;          % It is a column vector generally
end

% ### Protected properties
properties(Access = protected)
 	% Steady-state operating points
   	x_e;
 	u_e;
    xi;         % Angle difference
    
    % Used for Trapezoidal method
    Wk;
    fk;
    xk;
    uk;      
    
end

properties(GetAccess = protected, Constant)
	% Discretization methods: 
    % 1-Forward Euler, 2-Trapezoidal, 3-Virtual Damping
    DiscretizationMethod = 2;
end



%%
% =================================================
% Methods
% =================================================
% ### Static methods
methods(Static)
  	function [read1,read2,read3,read4] = ReadEquilibrium(obj)
        y_e = obj.StateSpaceEqu(obj,obj.x_e,obj.u_e,2);
        read1 = obj.x_e;
        read2 = obj.u_e;
        read3 = y_e;
        read4 = obj.xi;
    end
end

% ### Protected default methods provided by matlab
% Notes: The following methods are used for simulink model.
methods(Access = protected)

    % Perform one-time calculations, such as computing constants
    function setupImpl(obj)
        obj.SetString(obj);
        obj.Equilibrium(obj);
        obj.Linearization(obj,obj.x_e,obj.u_e);
        
        % Initialize uk and xk for the first step
        obj.uk = obj.u_e;
        obj.xk = obj.x_e;
        
        % For Trapezoidal method
        obj.Wk = inv(eye(length(obj.A)) - obj.Ts/2*obj.A);
    end

  	% Update states and calculate output in the same function
    % Notes: This function is replaced by "UpdateImpl" and "outputImpl"
    % function y = stepImpl(obj,u)
    % end
    
    % Update discreate states
    function updateImpl(obj, u)
        
        switch obj.DiscretizationMethod
            
            % ### Forward Euler 
            % s -> Ts/(z-1)
            % => x[k+1] - x[k] = Ts * f(x[k],u[k])
          	case 1
                f_xu = obj.StateSpaceEqu(obj, obj.x, u, 1);
                obj.x = f_xu * obj.Ts + obj.x;
                
            % ### Trapezoidal
            % s -> Ts/2*(z+1)/(z-1)
            % => x[k+1] - x[k] = Ts/2 * (f(x[k+1],u(k+1)) + f(x[k],u[k]))
            % => (x[k+1] - x[k])/Ts =
            % f((x[k+1]+x[k])/2,(u[k+1]+u[k])/2) = f(x[k],u[k]) + Ak*(x[k+1]-x[k])/2 + Bk*(u[k+1]-u[k])/2
            case 2    
  
                % Linear Trapezoidal
                obj.xk = obj.x;
                % obj.Linearization(obj,obj.xk,obj.uk);
                obj.Wk = inv(eye(length(obj.A)) - obj.Ts/2*obj.A);
                x_kp1_LinearTrapez = obj.Wk * (obj.Ts*(obj.StateSpaceEqu(obj,obj.xk,obj.uk,1) + obj.B*(u - obj.uk)/2) ) + obj.x;
                % uk and uk1 can not be used randomly.
                
                % Forward Euler
                x_k1_Euler = obj.StateSpaceEqu(obj, obj.x, u, 1)*obj.Ts + obj.x;
                
                % Split the states
                lx = length(obj.x);
            	x_k1_linear = x_kp1_LinearTrapez(1:(lx-1));
              	x_k1_others = x_k1_Euler((lx):end);
         
                % Update x[k] and u[k-1]
                obj.x = [x_k1_linear;
                         x_k1_others];
                obj.uk = u;
                
            % ###  Virtual damping: Euler -> Trapezoidal
            % s -> s/(1+s*Ts/2)
            case 3
                
                % Linearization
                obj.xk = obj.x;
                obj.Linearization(obj,obj.xk,obj.uk);
                obj.Wk = inv(eye(length(obj.A)) - obj.Ts/2*obj.A);
                x_k1_VD  = obj.Wk * obj.Ts * obj.StateSpaceEqu(obj,obj.xk,obj.uk,1) + obj.xk;

                % Forward Euler
                x_k1_Euler = obj.Ts * obj.StateSpaceEqu(obj, obj.xk, obj.uk, 1) + obj.xk;
                
                % Split the states
                lx = length(obj.x);
                x_k1_linear = x_k1_VD(1:(lx-1));
                x_k1_others = x_k1_Euler(lx);
                
                obj.x = [x_k1_linear;
                         x_k1_others];
            otherwise
        end
    end
        
    % Calculate output y
	function y = outputImpl(obj,u)
%         switch obj.DiscretizationMethod
%             case 2
                % obj.Linearization(obj,obj.x,obj.uk);
                % obj.C = zeros(size(obj.C));
                y = obj.StateSpaceEqu(obj, obj.x, u, 2) ...
                    + obj.Ts/2*obj.C*obj.Wk*obj.B*(u - obj.uk) ...
                    + obj.Ts*obj.C*obj.Wk*obj.StateSpaceEqu(obj,obj.x,obj.uk,1);
%             case 4
%                 xold_k1_VD = obj.x + obj.Ts/2*obj.Wk * obj.StateSpaceEqu(obj,obj.x,u,1);
%                 
%                 % Split the states
%                 lx = length(obj.x);
%                 xold_linear = xold_k1_VD(1:(lx-1));
%                 xold_others = obj.x(lx);
%                 
%                 xold = [xold_linear;
%                       	xold_others];
%                 
%                 y = obj.StateSpaceEqu(obj, xold, u, 2);
%             otherwise
%                 y = obj.StateSpaceEqu(obj, obj.x, u, 2);
%         end
    end
    
  	% Set direct or nondirect feedthrough status of input
%     function flag = isInputDirectFeedthroughImpl(~)
%        flag = false;
%     end

    % Initialize / reset discrete-state properties
    function resetImpl(obj)
        % Notes: x should be a column vector
        obj.x = obj.x0;
    end

    % Release resources, such as file handles
    function releaseImpl(obj)
    end

    % Define total number of inputs for system
    function num = getNumInputsImpl(obj)
        num = 1;
    end

    % Define total number of outputs for system
    function num = getNumOutputsImpl(obj)
        num = 1;
    end
    
    % Set the size of output
    function [size] = getOutputSizeImpl(obj)
        obj.SetString(obj);
        size = [length(obj.OutputString)];
    end
        
    % Set the characteristics of state
    function [size,dataType,complexity] = getDiscreteStateSpecificationImpl(obj, x)
        obj.SetString(obj);
        size = [length(obj.StateString)];
        dataType = 'double';
        complexity = false;
    end
    
end

end     % End class definition