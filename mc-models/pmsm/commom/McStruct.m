% --- Bus: tSnrHall ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'HA';
elems(1).DataType = 'uint8';
elems(2) = Simulink.BusElement;
elems(2).Name = 'HB';
elems(2).DataType = 'uint8';
elems(3) = Simulink.BusElement;
elems(3).Name = 'HC';
elems(3).DataType = 'uint8';

tSnrHall = Simulink.Bus;
tSnrHall.DataScope = 'Auto';
tSnrHall.Elements = elems;

% --- Bus: tSnrResolver ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'A';
elems(1).DataType = 'uint8';
elems(2) = Simulink.BusElement;
elems(2).Name = 'B';
elems(2).DataType = 'uint8';
elems(3) = Simulink.BusElement;
elems(3).Name = 'C';
elems(3).DataType = 'uint8';

tSnrResolver = Simulink.Bus;
tSnrResolver.DataScope = 'Auto';
tSnrResolver.Elements = elems;

% --- Bus: tSnrEncoder ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'A';
elems(1).DataType = 'uint8';
elems(2) = Simulink.BusElement;
elems(2).Name = 'B';
elems(2).DataType = 'uint8';
elems(3) = Simulink.BusElement;
elems(3).Name = 'C';
elems(3).DataType = 'uint8';

tSnrEncoder = Simulink.Bus;
tSnrEncoder.DataScope = 'Auto';
tSnrEncoder.Elements = elems;

% --- Bus: tSnrBemf ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'BemfA';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'BemfB';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'BemfC';
elems(3).DataType = 'uint16';

tSnrBemf = Simulink.Bus;
tSnrBemf.DataScope = 'Auto';
tSnrBemf.Elements = elems;

% --- Bus: tSnrVot ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'Va';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'Vb';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'Vc';
elems(3).DataType = 'uint16';

tSnrVot = Simulink.Bus;
tSnrVot.DataScope = 'Auto';
tSnrVot.Elements = elems;

% --- Bus: tSnrCur ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'Ia';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'Ib';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'Ic';
elems(3).DataType = 'uint16';

tSnrCur = Simulink.Bus;
tSnrCur.DataScope = 'Auto';
tSnrCur.Elements = elems;

% --- Bus: tMcSensor ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'AdcI';
elems(1).DataType = 'Bus: tSnrCur';
elems(2) = Simulink.BusElement;
elems(2).Name = 'AdcV';
elems(2).DataType = 'Bus: tSnrVot';
elems(3) = Simulink.BusElement;
elems(3).Name = 'Bemf';
elems(3).DataType = 'Bus: tSnrBemf';
elems(4) = Simulink.BusElement;
elems(4).Name = 'Hall';
elems(4).DataType = 'Bus: tSnrHall';
elems(5) = Simulink.BusElement;
elems(5).Name = 'Resolver';
elems(5).DataType = 'Bus: tSnrResolver';
elems(6) = Simulink.BusElement;
elems(6).Name = 'Encoder';
elems(6).DataType = 'Bus: tSnrEncoder';

tMcSensor = Simulink.Bus;
tMcSensor.DataScope = 'Auto';
tMcSensor.Elements = elems;

% --- Bus: tMcActuator ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'ActrState';
elems(1).DataType = 'uint8';
elems(2) = Simulink.BusElement;
elems(2).Name = 'PwmDuty';
elems(2).DataType = 'Bus: tActrDuty';

tMcActuator = Simulink.Bus;
tMcActuator.DataScope = 'Auto';
tMcActuator.Elements = elems;

% --- Bus: tActrDuty ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'AH';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'AL';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'BH';
elems(3).DataType = 'uint16';
elems(4) = Simulink.BusElement;
elems(4).Name = 'BL';
elems(4).DataType = 'uint16';
elems(5) = Simulink.BusElement;
elems(5).Name = 'CH';
elems(5).DataType = 'uint16';
elems(6) = Simulink.BusElement;
elems(6).Name = 'CL';
elems(6).DataType = 'uint16';

tActrDuty = Simulink.Bus;
tActrDuty.DataScope = 'Auto';
tActrDuty.Elements = elems;

% --- Bus: tAlgoPI ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'Kp';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'Ki';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'Ts';
elems(3).DataType = 'single';
elems(4) = Simulink.BusElement;
elems(4).Name = 'Integral';
elems(4).DataType = 'single';

tAlgoPI = Simulink.Bus;
tAlgoPI.DataScope = 'Auto';
tAlgoPI.Elements = elems;

% --- Bus: tMcAlgorithm ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'SpdPI';
elems(1).DataType = 'Bus: tAlgoPI';
elems(2) = Simulink.BusElement;
elems(2).Name = 'IdPI';
elems(2).DataType = 'Bus: tAlgoPI';
elems(3) = Simulink.BusElement;
elems(3).Name = 'IqPI';
elems(3).DataType = 'Bus: tAlgoPI';

tMcAlgorithm = Simulink.Bus;
tMcAlgorithm.DataScope = 'Auto';
tMcAlgorithm.Elements = elems;

% --- Bus: tDataDualU16 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'uint16';

tDataDualU16 = Simulink.Bus;
tDataDualU16.DataScope = 'Auto';
tDataDualU16.Elements = elems;

% --- Bus: tDataTriU16 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'uint16';

tDataTriU16 = Simulink.Bus;
tDataTriU16.DataScope = 'Auto';
tDataTriU16.Elements = elems;

% --- Bus: tDataQuadU16 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'uint16';
elems(4) = Simulink.BusElement;
elems(4).Name = 'D4';
elems(4).DataType = 'uint16';

tDataQuadU16 = Simulink.Bus;
tDataQuadU16.DataScope = 'Auto';
tDataQuadU16.Elements = elems;

% --- Bus: tDataPentaU16 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'uint16';
elems(4) = Simulink.BusElement;
elems(4).Name = 'D4';
elems(4).DataType = 'uint16';
elems(5) = Simulink.BusElement;
elems(5).Name = 'D5';
elems(5).DataType = 'uint16';

tDataPentaU16 = Simulink.Bus;
tDataPentaU16.DataScope = 'Auto';
tDataPentaU16.Elements = elems;

% --- Bus: tDataHexaU16 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'uint16';
elems(4) = Simulink.BusElement;
elems(4).Name = 'D4';
elems(4).DataType = 'uint16';
elems(5) = Simulink.BusElement;
elems(5).Name = 'D5';
elems(5).DataType = 'uint16';
elems(6) = Simulink.BusElement;
elems(6).Name = 'D6';
elems(6).DataType = 'uint16';

tDataHexaU16 = Simulink.Bus;
tDataHexaU16.DataScope = 'Auto';
tDataHexaU16.Elements = elems;

% --- Bus: tDataDualF32 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'single';

tDataDualF32 = Simulink.Bus;
tDataDualF32.DataScope = 'Auto';
tDataDualF32.Elements = elems;

% --- Bus: tDataTriF32 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'single';

tDataTriF32 = Simulink.Bus;
tDataTriF32.DataScope = 'Auto';
tDataTriF32.Elements = elems;

% --- Bus: tDataQuadF32 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'single';
elems(4) = Simulink.BusElement;
elems(4).Name = 'D4';
elems(4).DataType = 'single';

tDataQuadF32 = Simulink.Bus;
tDataQuadF32.DataScope = 'Auto';
tDataQuadF32.Elements = elems;

% --- Bus: tDataPentaF32 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'single';
elems(4) = Simulink.BusElement;
elems(4).Name = 'D4';
elems(4).DataType = 'single';
elems(5) = Simulink.BusElement;
elems(5).Name = 'D5';
elems(5).DataType = 'single';

tDataPentaF32 = Simulink.Bus;
tDataPentaF32.DataScope = 'Auto';
tDataPentaF32.Elements = elems;

% --- Bus: tDataHexaF32 ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'D1';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'D2';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'D3';
elems(3).DataType = 'single';
elems(4) = Simulink.BusElement;
elems(4).Name = 'D4';
elems(4).DataType = 'single';
elems(5) = Simulink.BusElement;
elems(5).Name = 'D5';
elems(5).DataType = 'single';
elems(6) = Simulink.BusElement;
elems(6).Name = 'D6';
elems(6).DataType = 'single';

tDataHexaF32 = Simulink.Bus;
tDataHexaF32.DataScope = 'Auto';
tDataHexaF32.Elements = elems;

% --- Bus: tMcDataFlow ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'AngleElc';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'WElc';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'WReqElc';
elems(3).DataType = 'single';
elems(4) = Simulink.BusElement;
elems(4).Name = 'DcBusCurRaw';
elems(4).DataType = 'uint16';
elems(5) = Simulink.BusElement;
elems(5).Name = 'DcBusCurFlt';
elems(5).DataType = 'single';
elems(6) = Simulink.BusElement;
elems(6).Name = 'DcBusVotRaw';
elems(6).DataType = 'uint16';
elems(7) = Simulink.BusElement;
elems(7).Name = 'DcBusVotFlt';
elems(7).DataType = 'single';
elems(8) = Simulink.BusElement;
elems(8).Name = 'CurPhRaw';
elems(8).DataType = 'Bus: tDataTriU16';
elems(9) = Simulink.BusElement;
elems(9).Name = 'CurPhFlt';
elems(9).DataType = 'Bus: tDataTriF32';
elems(10) = Simulink.BusElement;
elems(10).Name = 'CurAlBeFlt';
elems(10).DataType = 'Bus: tDataDualF32';
elems(11) = Simulink.BusElement;
elems(11).Name = 'CurDqFlt';
elems(11).DataType = 'Bus: tDataDualF32';
elems(12) = Simulink.BusElement;
elems(12).Name = 'CurDqReqFlt';
elems(12).DataType = 'Bus: tDataDualF32';
elems(13) = Simulink.BusElement;
elems(13).Name = 'VotDqFlt';
elems(13).DataType = 'Bus: tDataDualF32';
elems(14) = Simulink.BusElement;
elems(14).Name = 'VotAlBeFlt';
elems(14).DataType = 'Bus: tDataDualF32';
elems(15) = Simulink.BusElement;
elems(15).Name = 'VotPhFlt';
elems(15).DataType = 'Bus: tDataTriF32';
elems(16) = Simulink.BusElement;
elems(16).Name = 'DutyTriFlt';
elems(16).DataType = 'Bus: tDataTriF32';
elems(17) = Simulink.BusElement;
elems(17).Name = 'DutyHexaFlt';
elems(17).DataType = 'Bus: tDataHexaF32';

tMcDataFlow = Simulink.Bus;
tMcDataFlow.DataScope = 'Auto';
tMcDataFlow.Elements = elems;

% --- Bus: tMcType ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'MotorType';
elems(1).DataType = 'Enum: eMotorType';
elems(2) = Simulink.BusElement;
elems(2).Name = 'AlgorithmType';
elems(2).DataType = 'uint8';
elems(3) = Simulink.BusElement;
elems(3).Name = 'SensorType';
elems(3).DataType = 'uint8';
elems(4) = Simulink.BusElement;
elems(4).Name = 'ControlType';
elems(4).DataType = 'uint8';

tMcType = Simulink.Bus;
tMcType.DataScope = 'Auto';
tMcType.Elements = elems;

% --- Bus: tMcFault ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'SnrFault';
elems(1).DataType = 'uint8';
elems(2) = Simulink.BusElement;
elems(2).Name = 'AlgoFault';
elems(2).DataType = 'uint8';
elems(3) = Simulink.BusElement;
elems(3).Name = 'ActrFault';
elems(3).DataType = 'uint8';
elems(4) = Simulink.BusElement;
elems(4).Name = 'HwFault';
elems(4).DataType = 'uint8';

tMcFault = Simulink.Bus;
tMcFault.DataScope = 'Auto';
tMcFault.Elements = elems;

% --- Bus: tMcDebug ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'DebugEn';
elems(1).DataType = 'boolean';
elems(2) = Simulink.BusElement;
elems(2).Name = 'DebugChannel';
elems(2).DataType = 'uint8';
elems(3) = Simulink.BusElement;
elems(3).Name = 'DebugData';
elems(3).DataType = 'uint8';
elems(3).Dimensions = 8;

tMcDebug = Simulink.Bus;
tMcDebug.DataScope = 'Auto';
tMcDebug.Elements = elems;

% --- Bus: tMcTuning ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'SpdKp';
elems(1).DataType = 'uint16';
elems(2) = Simulink.BusElement;
elems(2).Name = 'SpdKi';
elems(2).DataType = 'uint16';
elems(3) = Simulink.BusElement;
elems(3).Name = 'IdKp';
elems(3).DataType = 'uint16';
elems(4) = Simulink.BusElement;
elems(4).Name = 'IdKi';
elems(4).DataType = 'uint16';
elems(5) = Simulink.BusElement;
elems(5).Name = 'IqKp';
elems(5).DataType = 'uint16';
elems(6) = Simulink.BusElement;
elems(6).Name = 'IqKi';
elems(6).DataType = 'uint16';
elems(7) = Simulink.BusElement;
elems(7).Name = 'AlignCurrent';
elems(7).DataType = 'uint16';
elems(8) = Simulink.BusElement;
elems(8).Name = 'AlignTime';
elems(8).DataType = 'uint16';
elems(9) = Simulink.BusElement;
elems(9).Name = 'OpenLoopAccel';
elems(9).DataType = 'uint16';
elems(10) = Simulink.BusElement;
elems(10).Name = 'TrackingGain';
elems(10).DataType = 'uint16';

tMcTuning = Simulink.Bus;
tMcTuning.DataScope = 'Auto';
tMcTuning.Elements = elems;

% --- EnumTypeDefinition: eSmEvent ---
eSmEvent = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eSmEvent, 1);
appendEnumeral(eSmEvent, 'EventNA', 0, '');
appendEnumeral(eSmEvent, 'InitDone', 1, '');
appendEnumeral(eSmEvent, 'FaultDetected', 2, '');
appendEnumeral(eSmEvent, 'StopDone', 3, '');
appendEnumeral(eSmEvent, 'Shutdown', 4, '');
appendEnumeral(eSmEvent, 'AlignDone', 5, '');
appendEnumeral(eSmEvent, 'OpenIfDone', 6, '');
appendEnumeral(eSmEvent, 'OpenVfDone', 7, '');
appendEnumeral(eSmEvent, 'TrackingDone', 8, '');
appendEnumeral(eSmEvent, 'RunBackward', 9, '');
appendEnumeral(eSmEvent, 'TrackingBackward', 10, '');
eSmEvent.StorageType = 'uint8';

% --- EnumTypeDefinition: eSmStates ---
eSmStates = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eSmStates, 1);
appendEnumeral(eSmStates, 'MC_STATE_RESET', 0, '');
appendEnumeral(eSmStates, 'MC_STATE_INIT', 1, '');
appendEnumeral(eSmStates, 'MC_STATE_IDLE', 2, '');
appendEnumeral(eSmStates, 'MC_STATE_FAULT', 3, '');
appendEnumeral(eSmStates, 'MC_STATE_READY', 4, '');
appendEnumeral(eSmStates, 'MC_STATE_READY_2_ALIGN', 5, '');
appendEnumeral(eSmStates, 'MC_STATE_ALIGN', 6, '');
appendEnumeral(eSmStates, 'MC_STATE_ALIGN_2_OPEN_IF', 7, '');
appendEnumeral(eSmStates, 'MC_STATE_OPEN_IF', 8, '');
appendEnumeral(eSmStates, 'MC_STATE_OPEN_IF_2_TRACKING', 9, '');
appendEnumeral(eSmStates, 'MC_STATE_TRACKING_2_OPEN_IF', 10, '');
appendEnumeral(eSmStates, 'MC_STATE_TRACKING', 11, '');
appendEnumeral(eSmStates, 'MC_STATE_TRACKING_2_RUN', 12, '');
appendEnumeral(eSmStates, 'MC_STATE_RUN_2_TRACKING', 13, '');
appendEnumeral(eSmStates, 'MC_STATE_RUN', 14, '');
appendEnumeral(eSmStates, 'MC_STATE_STOP', 15, '');
eSmStates.StorageType = 'uint8';

% --- Bus: tMcStateMachine ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'State';
elems(1).DataType = 'Enum: eSmStates';
elems(2) = Simulink.BusElement;
elems(2).Name = 'Cmd';
elems(2).DataType = 'Enum: eSmCmd';
elems(3) = Simulink.BusElement;
elems(3).Name = 'Event';
elems(3).DataType = 'Enum: eSmEvent';

tMcStateMachine = Simulink.Bus;
tMcStateMachine.DataScope = 'Auto';
tMcStateMachine.Elements = elems;

% --- EnumTypeDefinition: eMotorType ---
eMotorType = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eMotorType, 1);
appendEnumeral(eMotorType, 'MC_MOTOR_NA', 0, '');
appendEnumeral(eMotorType, 'MC_MOTOR_PMSM', 1, '');
appendEnumeral(eMotorType, 'MC_MOTOR_BLDC', 2, '');
appendEnumeral(eMotorType, 'MC_MOTOR_DCM', 3, '');
eMotorType.DefaultValue = 'MC_MOTOR_NA';

% --- EnumTypeDefinition: eSmCmd ---
eSmCmd = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eSmCmd, 1);
appendEnumeral(eSmCmd, 'SmReset', 0, '');
appendEnumeral(eSmCmd, 'FaultTrigger', 1, '');
appendEnumeral(eSmCmd, 'FaultClear', 2, '');
appendEnumeral(eSmCmd, 'AppOn', 3, '');
appendEnumeral(eSmCmd, 'AppOff', 4, '');
appendEnumeral(eSmCmd, 'MotorRun', 5, '');
appendEnumeral(eSmCmd, 'MotorStop', 6, '');
eSmCmd.DefaultValue = 'SmReset';
eSmCmd.StorageType = 'uint8';

% --- EnumTypeDefinition: eMcCtrl ---
eMcCtrl = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(eMcCtrl, 1);
appendEnumeral(eMcCtrl, 'McNotStart', 0, '');
appendEnumeral(eMcCtrl, 'McStart', 1, '');
appendEnumeral(eMcCtrl, 'McExit', 2, '');
eMcCtrl.DefaultValue = 'McNotStart';
eMcCtrl.StorageType = 'uint8';

% --- EnumTypeDefinition: ePosAlgo ---
ePosAlgo = Simulink.data.dictionary.EnumTypeDefinition;
removeEnumeral(ePosAlgo, 1);
appendEnumeral(ePosAlgo, 'PosNA', 0, '');
appendEnumeral(ePosAlgo, 'PosEncoder', 1, '');
appendEnumeral(ePosAlgo, 'PosHall', 2, '');
appendEnumeral(ePosAlgo, 'PosResolver', 3, '');
appendEnumeral(ePosAlgo, 'PosBemf', 4, '');
appendEnumeral(ePosAlgo, 'PosHfi', 5, '');
appendEnumeral(ePosAlgo, 'PosFlux', 6, '');
ePosAlgo.DefaultValue = 'PosNA';

% --- Bus: tMotorPara ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'NomVoltage';
elems(1).DataType = 'single';
elems(2) = Simulink.BusElement;
elems(2).Name = 'NomCurrent';
elems(2).DataType = 'single';
elems(3) = Simulink.BusElement;
elems(3).Name = 'NornSpd';
elems(3).DataType = 'single';
elems(4) = Simulink.BusElement;
elems(4).Name = 'PolePairNum';
elems(4).DataType = 'uint8';
elems(5) = Simulink.BusElement;
elems(5).Name = 'Ld';
elems(5).DataType = 'single';
elems(6) = Simulink.BusElement;
elems(6).Name = 'Lq';
elems(6).DataType = 'single';
elems(7) = Simulink.BusElement;
elems(7).Name = 'Rs';
elems(7).DataType = 'single';
elems(8) = Simulink.BusElement;
elems(8).Name = 'Bemf';
elems(8).DataType = 'single';
elems(9) = Simulink.BusElement;
elems(9).Name = 'Flux';
elems(9).DataType = 'single';
elems(10) = Simulink.BusElement;
elems(10).Name = 'RotorInertia';
elems(10).DataType = 'single';
elems(11) = Simulink.BusElement;
elems(11).Name = 'Kt';
elems(11).DataType = 'single';
elems(12) = Simulink.BusElement;
elems(12).Name = 'Ke';
elems(12).DataType = 'single';
elems(13) = Simulink.BusElement;
elems(13).Name = 'Fdamp';
elems(13).DataType = 'single';

tMotorPara = Simulink.Bus;
tMotorPara.DataScope = 'Auto';
tMotorPara.Elements = elems;

% --- Bus: tMcDrive ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'BasicCnt';
elems(1).DataType = 'uint32';
elems(2) = Simulink.BusElement;
elems(2).Name = 'McCtrl';
elems(2).DataType = 'Enum: eMcCtrl';
elems(3) = Simulink.BusElement;
elems(3).Name = 'McType';
elems(3).DataType = 'Bus: tMcType';
elems(4) = Simulink.BusElement;
elems(4).Name = 'StateMachine';
elems(4).DataType = 'Bus: tMcStateMachine';
elems(5) = Simulink.BusElement;
elems(5).Name = 'DebugInfo';
elems(5).DataType = 'Bus: tMcDebug';
elems(6) = Simulink.BusElement;
elems(6).Name = 'Tunning';
elems(6).DataType = 'Bus: tMcTuning';
elems(7) = Simulink.BusElement;
elems(7).Name = 'McCfg';
elems(7).DataType = 'Bus: tMcCfg';
elems(8) = Simulink.BusElement;
elems(8).Name = 'MotorPara';
elems(8).DataType = 'Bus: tMotorPara';

tMcDrive = Simulink.Bus;
tMcDrive.DataScope = 'Auto';
tMcDrive.Elements = elems;

% --- Bus: tMcCfg ---
clear elems;
elems(1) = Simulink.BusElement;
elems(1).Name = 'MotorNum';
elems(1).DataType = 'int8';
elems(2) = Simulink.BusElement;
elems(2).Name = 'TuningEn';
elems(2).DataType = 'boolean';
elems(3) = Simulink.BusElement;
elems(3).Name = 'DebugEn';
elems(3).DataType = 'boolean';
elems(4) = Simulink.BusElement;
elems(4).Name = 'SampleRate';
elems(4).DataType = 'uint32';
elems(5) = Simulink.BusElement;
elems(5).Name = 'PwmFreq';
elems(5).DataType = 'uint32';
elems(6) = Simulink.BusElement;
elems(6).Name = 'PosAlgo';
elems(6).DataType = 'Enum: ePosAlgo';

tMcCfg = Simulink.Bus;
tMcCfg.DataScope = 'Auto';
tMcCfg.Elements = elems;

