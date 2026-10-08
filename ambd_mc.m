% =================================================================================
% The MIT License
% MIT许可证
%
% <https://opensource.org/license/mit>
%
% SPDX short identifier / SPDX 短标识符：MIT
%
% Copyright (c) 2026 autoMBD
% 版权所有 (c) 2026 autoMBD
%
% Permission is hereby granted, free of charge, to any person obtaining a
% copy of this software and associated documentation files (the “Software”),
% to deal in the Software without restriction, including without limitation
% the rights to use, copy, modify, merge, publish, distribute, sublicense,
% and/or sell copies of the Software, and to permit persons to whom the
% Software is furnished to do so, subject to the following conditions:
% 特此向获得本软件及相关文档（合称“本软件”）副本的任何人免费授予不受限制地利用本软
% 件的许可，包括而不限于：使用、复制、修改、合并、发布、分发、分许可和/或销售本软
% 件副本，并允许本软件的接收者也获得前述许可，但须遵守以下条件：
%
% The above copyright notice and this permission notice shall be included
% in all copies or substantial portions of the Software.
% 以上版权声明及本许可声明应包含在本软件的所有副本或主要部分中。
%
% THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
% NONINFRINGEMENT. IN NO EVENT SHALLTHE AUTHORS OR COPYRIGHT
% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
% IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
% SOFTWARE.
% 本软件系“按原样”提供，不包含任何形式的明示或默示保证，包括但不限于适销性、特定
% 目的适用性及不侵权的保证。在任何情况下，无论是在合同、侵权或其他案件中，作者或版
% 权持有人均不对因本软件、或因本软件的使用或其他利用而引起的、引发的或与之相关的任
% 何权利主张、损害赔偿或其他责任承担责任。
% =================================================================================
% Project:     autoMBD Motor Control <https://github.com/autoMBD/AMBD-MC>
% File:        ambd_mc.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-08
% Version:     0.1.0
% Description: Dispatch MATLAB setup and isolated staging operations.
% =================================================================================

function info = ambd_mc(command,varargin)
%ambd_mc - Initialize motor families or prepare isolated target copies
%   INFO = ambd_mc("setup",FAMILY) initializes "pmsm", "bldc" or "all"
%   with enabled autoMBD HSP 0.1.0 and preserves saved calibrations.
%   Single families return their initializer information directly. "all"
%   returns Root, Family, HspVersion, Bldc and Pmsm. Retain INFO while
%   using models: its DictionaryConnection fields own dictionary enums.
%
%   INFO = ambd_mc("setup",FAMILY,SyncDictionary=TF) explicitly rebuilds
%   owned types and default calibrations when TF is true (default false).
%   Dirty dictionaries are rejected during synchronization.
%
%   INFO = ambd_mc("setup",FAMILY,Dictionary=FILE) selects a dictionary
%   for one family. A nonempty Dictionary is not supported for "all".
%
%   INFO = ambd_mc("setup",FAMILY,OutputDirectory=DIR) stores generated
%   artifacts below .agent-env. For "all", DIR contains bldc and pmsm
%   subdirectories. Name-value pairs also accept 'Name',VALUE syntax.
%
%   INFO = ambd_mc("stage",FAMILY,localSettingsFile) prepares "bldc" or
%   "pmsm" working copies below .agent-env/t, applying local JSON settings
%   only to those copies. It returns Root, Family, HspVersion, Stage,
%   Models, Target and Bldc or Pmsm. Dirty source state is rejected.
%   The JSON target field selects "s32k144" or "s32k344" (default).
%
%   ambd_mc("help") or ambd_mc displays this help without initializing.
%
%   See also mc_initialize, bldc_initialize

info=[];
% Select function help rather than the leading license header.
if nargin==0
    help('ambd_mc>ambd_mc')
    return
end
if ~isTextScalar(command) || ~ismember(string(command),["setup","stage","help"])
    error('ambd:Command','Choose a command: setup, stage or help.');
end
command=string(command);
if command=="help"
    if ~isempty(varargin)
        error('ambd:Arguments','The help command takes no additional arguments.');
    end
    help('ambd_mc>ambd_mc')
    return
end
if isempty(varargin)
    error('ambd:MissingArgument','Specify a motor family after %s.',command);
end
family=varargin{1};
allowed=["bldc","pmsm"];
if command=="setup",allowed(end+1)="all";end
if ~isTextScalar(family) || ~ismember(string(family),allowed)
    error('ambd:Family','For %s choose %s.',command,strjoin(allowed,', '));
end
family=string(family);
root=fileparts(mfilename('fullpath'));
if command=="stage"
    if numel(varargin)<2
        error('ambd:MissingArgument','Stage requires a local settings JSON file.');
    elseif numel(varargin)>2
        error('ambd:Arguments','Stage accepts only a family and settings file.');
    end
    settings=varargin{2};
    if ~isTextScalar(settings) || strlength(string(settings))==0
        error('ambd:SettingsFile','Specify a nonempty local settings JSON path.');
    end
    info=ambd_mc_stage(root,family,settings);
    return
end
options=parseSetupOptions(varargin(2:end));
if family=="all" && options.Dictionary~=""
    error('ambd:SharedDictionary', ...
        'Use separate setup calls to select each family dictionary.');
end
info=ambd_mc_setup(root,family,options);
if family=="bldc",info=info.Bldc;end
if family=="pmsm",info=info.Pmsm;end
end

function options=parseSetupOptions(args)
options=struct('Dictionary',"",'OutputDirectory',"",'SyncDictionary',false);
if mod(numel(args),2)~=0
    error('ambd:Option','Setup options require name-value pairs.');
end
for index=1:2:numel(args)
    name=args{index};
    if ~isTextScalar(name) || ~isfield(options,char(name))
        error('ambd:Option', ...
            'Setup options are Dictionary, OutputDirectory and SyncDictionary.');
    end
    name=char(name);
    value=args{index+1};
    if strcmp(name,'SyncDictionary')
        if ~islogical(value) || ~isscalar(value)
            error('ambd:Option','SyncDictionary must be a logical scalar.');
        end
    else
        if ~isTextScalar(value)
            error('ambd:Option','%s must be a text scalar.',name);
        end
        value=string(value);
    end
    options.(name)=value;
end
end

function valid=isTextScalar(value)
valid=(ischar(value) && (isrow(value) || isequal(size(value),[0 0]))) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value));
end
