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
% File:        validate_pil.m
% Author:      autoMBD <tkung.lqk@foxmail.com>
% Date:        2026-10-07
% Version:     0.1.0
% Description: Verify real S32K344 execution against a bounded Normal reference.
% =================================================================================

function result = validate_pil(model,family,outputDirectory)
%validate_pil - Compare a real S32K344 replay with its Normal reference
%   RESULT = validate_pil(MODEL,FAMILY,OUTPUTDIRECTORY) runs both modes
%   against the same bounded input fixture, saves traces and logs, and
%   requires actual PIL metadata, a download receipt, exact typed output
%   equality and fault gate shutdown. MODEL must be an isolated HSP copy.
%
%   See also ambd_mc, ambd.pil_fixture, ambd.compare_outputs

if ~isfolder(outputDirectory),mkdir(outputDirectory);end
result=struct('Model',model,'Family',family,'Passed',false,'Stage','running');
normal=[];target=[];
writeResult(outputDirectory,result);
try
    [in,faultSamples]=ambd.pil_fixture(model,family);
    in=in.setModelParameter('SimulationMode','normal');
    failure=[];normalLog=evalc('try;normal=sim(in);catch exception;failure=exception;end');
    writeText(fullfile(outputDirectory,'normal.log'),normalLog);
    if ~isempty(failure),rethrow(failure);end
    in=in.setModelParameter('SimulationMode',autombd.hsp.pil.simulationMode('pil'));
    failure=[];targetLog=evalc('try;target=sim(in);catch exception;failure=exception;end');
    writeText(fullfile(outputDirectory,'pil.log'),targetLog);
    if ~isempty(failure),rethrow(failure);end
    result.ExecutionMode=target.SimulationMetadata.ModelInfo.SimulationMode;
    result.Samples=numel(target.yout{1}.Values.Time);
    result.Comparison=ambd.compare_outputs(normal.yout,target.yout);
    result.FaultGateOff=all(~target.yout{5}.Values.Data(faultSamples));
    result.GateWasActive=any(target.yout{5}.Values.Data);
    cfg=autombd.hsp.config.read(model);
    receiptFile=fullfile(cfg.outputDirectory,'pil','download-result.json');
    receipt=jsondecode(fileread(receiptFile));
    result.DownloadReceipt=receiptFile;
    result.Elf=receipt.elf;
    result.ElfSha256=receipt.elfSha256;
    result.LinkerWarnings=regexp(targetLog,'[^\r\n]*warning:[^\r\n]*','match');
    result.Passed=strcmpi(result.ExecutionMode,'processor-in-the-loop (pil)') ...
        && result.Samples==129 && result.Comparison.Passed && result.FaultGateOff ...
        && result.GateWasActive && strcmp(receipt.status,'command-completed') ...
        && receipt.executionRequested && isfile(receipt.elf) ...
        && strcmpi(autombd.hsp.pil.sha256File(receipt.elf),receipt.elfSha256);
    result.Stage='complete';
    save(fullfile(outputDirectory,'traces.mat'),'normal','target','in','result','-v7.3');
    writeResult(outputDirectory,result);
    assert(result.Passed,'ambd:PilAcceptance','PIL acceptance failed for %s; see %s.',model,outputDirectory);
catch exception
    result.Passed=false;result.Stage='failed';result.Error=exception.message;
    if isa(normal,'Simulink.SimulationOutput')&&isa(target,'Simulink.SimulationOutput')
        save(fullfile(outputDirectory,'traces.mat'),'normal','target','in','result','-v7.3');
    end
    writeResult(outputDirectory,result);rethrow(exception);
end
end

function writeResult(folder,result)
writeText(fullfile(folder,'result.json'),jsonencode(result,PrettyPrint=true));
end

function writeText(path,text)
fid=fopen(path,'w','n','UTF-8');
assert(fid>=0,'ambd:ReportWrite','Cannot write %s.',path);
cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);
end
