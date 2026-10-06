function info = bldc_setup(options)
%bldc_setup - Add BLDC model paths and verify its dictionary
%   INFO = bldc_setup initializes the BLDC source and model search paths.
%   INFO = bldc_setup(SyncDictionary=true) explicitly resets BLDC defaults.
%   See also bldc_initialize

% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
arguments
    options.SyncDictionary {mustBeA(options.SyncDictionary,'logical'),mustBeScalarOrEmpty} = false
end
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'mc-models','bldc'));
info=bldc_initialize(SyncDictionary=options.SyncDictionary);
end
