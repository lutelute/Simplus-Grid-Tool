% This function creates a simulink model according to custormer data.

% Author(s): Yitong Li

%% Notes
%
% A very useful function:
% get_param(gcb,'ObjectParameters')
% The second input argument can be: 'Object Paramters', 'DialogParamters',
% 'PortConnectivity', 'PortHandles', 'ScopeConfiguration'

%%
function main_simulink(Name_Model,W0,ListLine,N_Bus,N_Branch,N_Device,DeviceType)

%% Common variables
NewSimulinkModel('ModelName',Name_Model);
Name_Lib = 'Simplex';
Name_LibFile = 'simplex_lib';
% load_system(Name_LibFile);

%% Organize data
fb = ListLine(:,1); % From bus
tb = ListLine(:,2); % To bus
R  = ListLine(:,3);
X  = ListLine(:,4);
B  = ListLine(:,5);
G  = ListLine(:,6);

%% Add powergui into simulink model
Position_powergui = [0,0];
Size_powergui = [70,30];

FullName_powergui = [Name_Model '/powergui'];
add_block(['powerlib/powergui'],FullName_powergui);
set_param(gcb,'position',[Position_powergui,Position_powergui+Size_powergui]);
set_param(gcb,'SimulationMode','Discrete');
set_param(gcb,'SampleTime','Ts');

%% Add buses into simulink model
% Parameter
Size_Bus = [30,65];
Position_Bus{1} = [100,200];

% Increase x_distance when the number of mutual branches in creases
[~,MaxCounterToBus,~] = mode(fb);
Distance_Bus = [200+100*MaxCounterToBus,300];  

% Add bus
for i = 1:N_Bus
    
    Name_Bus{i} = ['Bus' num2str(i)];
    FullName_Bus{i} = [Name_Model '/' Name_Bus{i}];
    add_block([Name_LibFile '/Three-Phase Bus'],FullName_Bus{i});
    set_param(gcb,'position',[Position_Bus{i},Position_Bus{i}+Size_Bus]);
    Position_Bus{i+1} = Position_Bus{i} + Distance_Bus;

end

%% Add device into simulink model
% Parameter
Size_Device = [50,90];
Shift_Device = [-150,0];

% Add device
for i = 1:N_Device
    switch DeviceType{i}
        case 0
            Name_Device{i} = ['SM' num2str(i)];
            FullName_Device{i} = [Name_Model '/' Name_Device{i}];
            add_block([Name_LibFile '/Synchronous Machine (dq-Frame System Object)'],FullName_Device{i});
        case 10
            Name_Device{i} = ['VSI-PLL' num2str(i)];
            FullName_Device{i} = [Name_Model '/' Name_Device{i}];
            add_block([Name_LibFile '/Grid-Following Voltage-Source Inverter (dq-Frame System Object)'],FullName_Device{i});
        case 20
            Name_Device{i} = ['VSI-Droop' num2str(i)];
            FullName_Device{i} = [Name_Model '/' Name_Device{i}];
            add_block([Name_LibFile '/Grid-Forming Voltage-Source Inverter (dq-Frame System Object)'],FullName_Device{i});
        otherwise
    end
    
    % Set parameter
    set_param(gcb,'Sbase','Sbase');
    set_param(gcb,'Vbase','Vbase');
    set_param(gcb,'Wbase','Wbase');
    set_param(gcb,'Ts','Ts');
    set_param(gcb,'DeviceType',['DeviceType{' num2str(i) '}']);
    set_param(gcb,'DevicePara',['DevicePara{' num2str(i) '}']);
    set_param(gcb,'PowerFlow',['PowerFlow{' num2str(i) '}']);
    set_param(gcb,'x0',['x_e{' num2str(i) '}']);
    set_param(gcb,'OtherInputs',['OtherInputs{' num2str(i) '}']);
    
    % The position of device is set by referring to the position of correpsonding bus
    Position_Device{i} = Position_Bus{i} + Shift_Device;
    set_param(FullName_Device{i},'position',[Position_Device{i},Position_Device{i}+Size_Device]);
    set_param(FullName_Device{i},'Orientation','left');
         
end

%% Connect device to bus
for i = 1:N_Device
	add_line(Name_Model,...
        {[Name_Device{i} '/Lconn1'],[Name_Device{i} '/Lconn2'],[Name_Device{i} '/Lconn3']},...
        {[Name_Bus{i} '/Lconn1'],[Name_Bus{i} '/Lconn2'],[Name_Bus{i} '/Lconn3']},...
        'autorouting','smart');
end

%% Add device scope, ground, etc
% Paramter
Size_DeviceGND = [20,20];
Shift_DeviceGND = [20,20];

Size_DeviceScope = [30,Size_Device(2)];
Shift_DeviceScope = [-100,0];

Size_DeviceScopeBus = [5,Size_Device(2)];
Shift_DeviceScopeBus = [-30,0];

% Add block
for i = 1:N_Device
  	% Add device ground
    Name_DeviceGND{i} = ['D-GND' num2str(i)];
    FullName_DeviceGND{i} = [Name_Model '/' Name_DeviceGND{i}];
    add_block('powerlib/Elements/Ground',FullName_DeviceGND{i});
    PortPosition_Device{i} = get_param(FullName_Device{i},'PortConnectivity');
    % Position of device ground is set by referring to the position of
    % corresponding device
    Position_DeviceGND{i} = PortPosition_Device{i}(5).Position;
    Position_DeviceGND{i} = Position_DeviceGND{i} + Shift_DeviceGND;
    set_param(FullName_DeviceGND{i},'position',[Position_DeviceGND{i},Position_DeviceGND{i}+Size_DeviceGND]);
    % Connect device to device ground
    add_line(Name_Model,[Name_Device{i} '/LConn4'],[Name_DeviceGND{i} '/LConn1'],...
            'autorouting','smart');
        
  	% Add device scope bus
    Name_DeviceScopeBus{i} = ['DS-Bus' num2str(i)];
    FullName_DeviceScopeBus{i} = [Name_Model '/' Name_DeviceScopeBus{i}];
    add_block('simulink/Signal Routing/Bus Selector',FullName_DeviceScopeBus{i});
    set_param(gcb,'Orientation','left');
    Position_DeviceScopeBus{i} = Position_Device{i} + Shift_DeviceScopeBus;
    set_param(gcb,'position',[Position_DeviceScopeBus{i},Position_DeviceScopeBus{i}+Size_DeviceScopeBus]);
    Output_DeviceScopeBus = ['v_dq,i_dq,v_abc,i_abc,w,theta'];
    Length_DeviceMeasurement = 6;
    set_param(gcb,'OutputSignals',Output_DeviceScopeBus);
    PortHandles_DeviceScopeBus{i} = get_param(gcb,'PortHandles');
        
 	% Conect scope bus to device
    add_line(Name_Model, {[Name_Device{i} '/1']}, {[Name_DeviceScopeBus{i} '/1']});
    
    % Add device scope
    Name_DeviceScope{i} = ['D-Scope' num2str(i)];
    FullName_DeviceScope{i} = [Name_Model '/' Name_DeviceScope{i}];
    add_block('simulink/Sinks/Scope',FullName_DeviceScope{i});
    set_param(gcb,'NumInputPorts',num2str(Length_DeviceMeasurement));
    set_param(gcb,'LayoutDimensionsString',['[' num2str(Length_DeviceMeasurement) ' 1]']);
    PortHandles_DeviceScope{i} = get_param(gcb,'PortHandles');
    set_param(gcb,'Orientation','left');
    Position_DeviceScope{i} = Position_Device{i} + Shift_DeviceScope;
    set_param(gcb,'position',[Position_DeviceScope{i},Position_DeviceScope{i}+Size_DeviceScope]);

    % Connect scope to scope bus
    for k = 1:Length_DeviceMeasurement
        add_line(Name_Model,{PortHandles_DeviceScopeBus{i}.Outport(k)},{PortHandles_DeviceScope{i}.Inport(k)});
    end 
end

%% Add branches into simulink model
% Parameter
Size_MutualBranch = [Size_Bus(2),Size_Bus(2)];
Size_SelfBranch   = Size_MutualBranch;
Shift_SelfBranch  = [+100,+100];
Shift_MutualBranch = [+100,+100];
Counter_ToBus = zeros(max(tb),1);

Size_BranchGND = Size_DeviceGND;
Shift_BranchGND = [-Size_DeviceGND(1)/2,30];
Counter_BranchGND = 0;

% Add branch
for i = 1:N_Branch
    
    % Initialize the postion of branch
    Position_Branch{i} = [Position_Bus{tb(i)}(1),Position_Bus{fb(i)}(2)];
    Name_Branch{i} = ['Branch' num2str(fb(i)) num2str(tb(i))];
    FullName_Branch{i} = [Name_Model '/' Name_Branch{i}];
    
    % ### Add self branch
    if fb(i) == tb(i)
        % Add block
        add_block(['powerlib/Elements/Three-Phase Parallel RLC Branch'],FullName_Branch{i});
        Position_Branch{i} = Position_Branch{i} + Shift_SelfBranch;
        set_param(FullName_Branch{i},'position',[Position_Branch{i},Position_Branch{i}+Size_SelfBranch]);
        set_param(FullName_Branch{i},'Orientation','down');
        set_param(FullName_Branch{i},'Measurements','None');
        
     	% Add self-branch ground
        Counter_BranchGND = Counter_BranchGND + 1;
        % if Counter_BranchGND == 1
        if 1
            Name_BranchGND{i} = ['B-GND' num2str(i)];
            FullName_BranchGND{i} = [Name_Model '/' Name_BranchGND{i}];
            add_block('powerlib/Elements/Ground',FullName_BranchGND{i});
            PortPosition_Branch{i} = get_param(FullName_Branch{i},'PortConnectivity');
            Position_BranchGND{i} = PortPosition_Branch{i}(5).Position;
            Position_BranchGND{i} = Position_BranchGND{i} + Shift_BranchGND;
            set_param(FullName_BranchGND{i},'position',[Position_BranchGND{i},Position_BranchGND{i}+Size_BranchGND]);
           	add_line(Name_Model,[Name_Branch{i} '/RConn2'],[Name_BranchGND{i} '/LConn1'], ...
                'autorouting','smart');
        end
        
     	% Connect the floating terminals of self-branch to Y configuration
        add_line(Name_Model,...
            {[Name_Branch{i} '/Rconn2'],[Name_Branch{i} '/Rconn2']},...
            {[Name_Branch{i} '/Rconn1'],[Name_Branch{i} '/Rconn3']});
        
        % Assume the self-branch is pure RC
        if ~((R(i)==0) && (X(i)==0))
            error(['Error: the self branch contains L or R']);
        end
        if (G(i)==0) && (B(i)==0)
            error(['Error: open circuit']);
        elseif G(i)==0      % Pure capacitance
            set_param(FullName_Branch{i},'BranchType','C');
        elseif B(i)==0      % Pure resistance
            set_param(FullName_Branch{i},'BranchType','R');
        else                % RC branch
            set_param(FullName_Branch{i},'BranchType','RC');
        end
        
        % Set customer data
    	set_param(FullName_Branch{i},'Capacitance',num2str(B(i)/W0));
     	set_param(FullName_Branch{i},'Resistance',num2str(1/G(i)));
        
    % ### Add mutual branch
    else
        % Add block
        add_block(['powerlib/Elements/Three-Phase Series RLC Branch'],FullName_Branch{i});
        Counter_ToBus(tb(i)) = Counter_ToBus(tb(i)) + 1;
        Position_Branch{i} = Position_Branch{i} + [Shift_MutualBranch(1)*Counter_ToBus(tb(i)),Shift_MutualBranch(2)];
        set_param(FullName_Branch{i},'position',[Position_Branch{i},Position_Branch{i}+Size_MutualBranch]);
        set_param(FullName_Branch{i},'Orientation','down');
        set_param(FullName_Branch{i},'Measurements','None');
        
        % Assume the mutual-branch is pure RL
        if ~(isinf(G(i)) || isinf(B(i)))
            error('Error: the mutual branch contains B or G');      
        end
        if (R(i)==0) && (X(i)==0)
            error('Error: short circuit')
        elseif R(i)==0      % Pure inductance
            set_param(FullName_Branch{i},'BranchType','L');
        elseif X(i)==0      % Pure resistance
            set_param(FullName_Branch{i},'BranchType','R');
        else                % RL branch
            set_param(FullName_Branch{i},'BranchType','RL');    
        end
        
        % Set customer data
        set_param(FullName_Branch{i},'Resistance',num2str(R(i)));
     	set_param(FullName_Branch{i},'Inductance',num2str(X(i)/W0))
    end
    
end

%% Connect branch to bus
% Connect mutual-branch to the output port of bus
for i = 1:N_Branch
    if fb(i) ~= tb(i)
        
        From = fb(i);
        To = tb(i);
        
        % Connect branch and "from bus"
        add_line(Name_Model,...
            {[Name_Bus{From} '/Rconn1'],[Name_Bus{From} '/Rconn2'],[Name_Bus{From} '/Rconn3']},...
            {[Name_Branch{i} '/Lconn1'],[Name_Branch{i} '/Lconn2'],[Name_Branch{i} '/Lconn3']},...
            'autorouting','smart');
        
        % Connect branch and "to bus"
     	add_line(Name_Model,...
            {[Name_Bus{To} '/Rconn1'],[Name_Bus{To} '/Rconn2'],[Name_Bus{To} '/Rconn3']},...
            {[Name_Branch{i} '/Rconn1'],[Name_Branch{i} '/Rconn2'],[Name_Branch{i} '/Rconn3']},...
            'autorouting','smart');
    end
end

% Connect self-branch to the output port of bus
% Remarks: Doing this procedure seperately with the mutual-branch procedure
% because this will lead to a better the autorouting quality of simulink.
for i = 1:N_Branch
  	if fb(i) == tb(i)
        
        From = fb(i);     % Index number of the bus
        
        % Connect self-branch to bus
        add_line(Name_Model,...
            {[Name_Bus{From} '/Rconn1'],[Name_Bus{From} '/Rconn2'],[Name_Bus{From} '/Rconn3']},...
            {[Name_Branch{i} '/Lconn1'],[Name_Branch{i} '/Lconn2'],[Name_Branch{i} '/Lconn3']},...
            'autorouting','smart');
    end
end

end
