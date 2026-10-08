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
% File:        ambd_concurrent_probe.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-08
% Version:     0.1.0
% Description: Run hardware-free isolation acceptance in an owned MATLAB instance.
% =================================================================================

function ambd_concurrent_probe(repo,output)
%ambd_concurrent_probe - Exercise initialization and host simulation
%   ambd_concurrent_probe(REPO,OUTPUT) runs the HSP suite and both motor
%   host simulations, saving actual process and directory evidence.
%
%   See also ambd_mc, runtests

owned=ambd_instance_root(repo);
result=struct('pid',ambd_matlab_pid(),'temp',tempdir,'work',pwd, ...
    'instance',owned,'passed',false,'phase',"hsp-tests");
try
    tests=runtests(fullfile(repo,'tests','hsp'));
    result.tests=struct('total',numel(tests),'passed',sum([tests.Passed]), ...
        'failed',sum([tests.Failed]),'incomplete',sum([tests.Incomplete]));
    assertSuccess(tests);
    assert(~any([tests.Incomplete]),'ambd:IncompleteTests','HSP tests were incomplete.');
    result.phase="setup";
    writeReport(output,result);
    info=ambd_mc('setup','all');
    result.bldcTypes=info.Bldc.GeneratedTypeFile;
    result.pmsmTypes=info.Pmsm.GeneratedTypeFile;
    assertOwned(result.bldcTypes,owned);assertOwned(result.pmsmTypes,owned);
    cfg=Simulink.fileGenControl('getConfig');
    result.cache=cfg.CacheFolder;result.codegen=cfg.CodeGenFolder;
    assertOwned(result.cache,owned);assertOwned(result.codegen,owned);
    result.phase="host-simulation";
    writeReport(output,result);
    bldcResult=bldc_run_host_case("hall_steps","Normal");
    pmsmResult=mc_run_host_case("FOC_PIL_Algth_top","sensored_steps","Normal");
    assert(bldcResult.Passed && pmsmResult.Passed,'ambd:HostSimulation', ...
        'A closed-loop host scenario failed.');
    assertOwned(bldcResult.TraceFile,owned);assertOwned(pmsmResult.TraceFile,owned);
    result.bldc=struct('passed',bldcResult.Passed,'samples',bldcResult.Samples, ...
        'trace',bldcResult.TraceFile);
    result.pmsm=struct('passed',pmsmResult.Passed,'samples',pmsmResult.Samples, ...
        'trace',pmsmResult.TraceFile);
    cfg=Simulink.fileGenControl('getConfig');
    result.finalCache=cfg.CacheFolder;result.finalCodegen=cfg.CodeGenFolder;
    assertOwned(result.finalCache,owned);assertOwned(result.finalCodegen,owned);
    result.workAfter=pwd;assertOwned(pwd,owned);
    result.passed=true;result.phase="complete";
catch exception
    result.errorIdentifier=exception.identifier;
    result.error=getReport(exception,'extended','hyperlinks','off');
    writeReport(output,result);
    rethrow(exception);
end
writeReport(output,result);
disp('AMBD_CONCURRENT_PASS');
end

function assertOwned(value,root)
assert(startsWith(lower(string(value)),lower(string(root)+filesep)), ...
    'ambd:SharedOutput','An output escaped this MATLAB instance: %s',value);
end

function writeReport(file,result)
fid=fopen(file,'w','n','UTF-8');
assert(fid>=0,'ambd:ConcurrentReport','Cannot write concurrency evidence.');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'%s',jsonencode(result,PrettyPrint=true));
end
