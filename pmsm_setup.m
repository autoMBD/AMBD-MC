function info = pmsm_setup(varargin)
%PMSM_SETUP Initialize the repository's PMSM models without hardware tools.
%   INFO = PMSM_SETUP initializes paths and verifies saved types/parameters.
%   INFO = PMSM_SETUP(SyncDictionary=true) explicitly regenerates owned data.
% SPDX-License-Identifier: MIT
% Copyright (c) 2026 autoMBD
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'mc-models','pmsm'));
info=mc_initialize(varargin{:});
addpath(fullfile(root,'mc-models','pmsm','platform','codegen'));
end
