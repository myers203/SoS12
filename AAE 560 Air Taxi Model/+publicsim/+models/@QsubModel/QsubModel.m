classdef QsubModel < handle
    %QSUBMODEL QS
    %   Detailed explanation goes here
    
    properties
        runLogPath='./tmp';
        useMcc=0;
        qsubArgs = 'qsub -l nodes=1:ppn=1,walltime=02:00:00' % This is for the submitter.
        % If you need more than 2 hours you're probably doing something wrong.
        % For rice, will want to add naccesspolicy=singleuser
    end
        
    
    methods
        function obj = QsubModel()
        end
        
        function createRun(obj,runId,functionName,varargin)
            
            %Example:
            %QsubModel.createRun(1,'QsubModel.collectInputSample',[1:20]);
            
            base_param_num=3; % obj, runId, functionName
            
            execDir=pwd();
            data_dir=strcat(execDir,'/rundata');
            script_dir=strcat(execDir,'/scripts');
            mkdir(data_dir);
            mkdir(script_dir);
            
            lenparam=[];
            for i=base_param_num+1:nargin
                param=varargin{i-base_param_num};
                if isa(param, 'char')
                    paramLength = 1;
                else
                    paramLength = length(param);
                end
                lenparam(end+1)=paramLength; %#ok<AGROW>
            end
            
            x=1:max(max(lenparam));
            n=length(lenparam);
            m = length(x);
            X = cell(1, n);
            [X{:}] = ndgrid(x);
            X = X(end : -1 : 1);
            y = cat(n+1, X{:});
            y = reshape(y, [m^n, n]);
            
            for i=1:length(lenparam)
                testval=lenparam(i);
                testvect=y(:,i);
                y(testvect>testval,:)=[];
            end
            
            num_job_id=size(y, 1);
            
            submit_script=strcat(script_dir,'/run_',num2str(runId),'.sh');
            fid=fopen(submit_script,'w');
            
            load_script=strcat(script_dir,'/load_run_',num2str(runId),'.m');
            lfid=fopen(load_script,'w');
            sizestr=sprintf('%.0f,',max(y));
            sizestr(end)='';
            dataname=sprintf('run%d_data',runId);
            fprintf(lfid,'%s=cell(%s);\n',dataname,sizestr);
            
            base_store_file=strcat(script_dir,'/run',num2str(runId),'/');
            mkdir(base_store_file);
            
            for i=1:num_job_id
                idx=y(i,:);
                log_temp_dir=sprintf('/tmp/log_run%d_job%d/',runId,i);
                param_string=[ '''''' log_temp_dir '''''' ','];
                for k=1:length(idx)
                    tmp=varargin{k};
                    
                    detail = whos('tmp');
                    switch detail.class
                        case 'char'
                            param_string = strcat(param_string, '''''', tmp, '''''', ',');
                        case 'cell'
                            cellTmp = tmp{idx(k)};
                            cellDetail = whos('cellTmp');
                            switch cellDetail.class
                                case 'char'
                                    param_string = strcat(param_string, '''''', tmp{idx(k)}, '''''', ',');
                                otherwise
                                    param_string=strcat(param_string,num2str(tmp(idx(k))),',');
                            end
                        otherwise
                            param_string=strcat(param_string,num2str(tmp(idx(k))),',');
                    end
                end
                param_string(end)='';
                exec_str=strcat(functionName,'(',param_string,')');
                store_file=strcat(base_store_file,num2str(i),'.sh');
                job_data_dir=strcat(data_dir,'/run',num2str(runId),'/job',num2str(i));
                
                obj.createScript(store_file,log_temp_dir,exec_str,execDir,job_data_dir,runId,i);

                fprintf(fid,'%s %s\n',obj.qsubArgs,store_file);

                idxstr=sprintf('%.0f,',idx);
                idxstr(end)='';
                loaddata_file=strcat(job_data_dir,'/run',num2str(runId),'_job',num2str(i),'.mat');
                fprintf(lfid,'try\n');
                fprintf(lfid,'x=load(''%s'');\n',loaddata_file);
                fprintf(lfid,'%s{%s}=x.output;\n',dataname,idxstr);
                fprintf(lfid,'catch e\nx=%d;\n ',i);
                fprintf(lfid,'%s{%s}=x;\nend\n\n',dataname,idxstr);
            end
            
            for i=base_param_num+1:nargin
                k=i-base_param_num;
                param=varargin{k};
                detail = whos('param');
                switch detail.class
                    case 'cell'
                        fprintf(lfid, 'run%d_input.v%d={', runId, k);
                        for ind = 1:numel(param)
                            fprintf(lfid, '%s', mat2str(param{ind}));
                            if ind < numel(param)
                                fprintf(lfid, ',');
                            end
                        end
                        fprintf(lfid, '};\n');
                    otherwise
                        fprintf(lfid,'run%d_input.v%d=%s;\n',runId,k,mat2str(param));
                end
            end
            
            finalfile=strcat(data_dir,'/run',num2str(runId),'.mat');
            %Octave:
            fprintf(lfid,'save(''-v7'',''%s'',''%s'',''run%d_input'');\n',finalfile,dataname,runId);
            %MATLAB:
            %fprintf(lfid,'save(''%s'',''%s'',''run%d_input'');\n',finalfile,dataname,run_id);
            
            fclose(fid);
            fclose(lfid);
            
            obj.logRun(runId,functionName,varargin);
            
        end
        
        function [ ] = createScript(obj,store_file,log_temp_dir,exec_str,exec_dir,data_dir,run_id,job_id)
            
            fid=fopen(store_file,'w');
            
            fprintf(fid,'#!/bin/bash\n');
            fprintf(fid,'#PBS -o ''%s/qsub.out''\n',data_dir);
            fprintf(fid,'#PBS -e ''%s/qsub.err''\n',data_dir);
            fprintf(fid,'cd %s\n',exec_dir);
            fprintf(fid,'mkdir -p %s\n',data_dir);
            save_file=strcat(data_dir,'/run',num2str(run_id),'_job',num2str(job_id),'.mat');
            output_temp=sprintf('/tmp/console_run%d_job%d.out',run_id,job_id);
            fprintf(fid,'mkdir -p %s\n',log_temp_dir);
            if obj.useMcc==0
                fprintf(fid,'matlab -nodisplay -nosplash -nodesktop > %s 2>&1 << EOF\n',output_temp);
                fprintf(fid,'publicsim.models.QsubModel.execRun(''%s'',''%s'');\n',save_file,exec_str);
                fprintf(fid,'dbstack\n');
                fprintf(fid,'exit\n');
                fprintf(fid,'EOF\n');
            else
                fprintf(fid,'matlab -nodisplay -nosplash -nodesktop > %s 2>&1 << EOF\n',output_temp);
            end
            fprintf(fid,'gzip %s\n mv %s.gz %s\n',output_temp,output_temp,data_dir);
            fprintf(fid,'rm -rf %s\n',log_temp_dir);
            fprintf(fid,'rm -rf %s\n',output_temp);
            
            fclose(fid);
        end
    end
    
    methods(Static)
        function execRun(saveFile,execStr)
            
            [output]=eval(execStr); %#ok<NASGU>
            
            save(saveFile,'output');
        end
        
        function outString = argToString(inputArg)
            detail = whos('inputArg');
            
            startString = '';
            endString = '';
            argString = '';
            switch detail.class
                case 'double'
                    if numel(inputArg) > 1
                        startString = '[';
                        endString = ']';
                        rows = size(inputArg, 1);
                        cols = size(inputArg, 2);
                        for j = 1:cols
                            for k = 1:rows
                                argString = [argString, num2str(inputArg(k, j))]; %#ok<AGROW>
                                if k ~= rows
                                    argString = [argString, ', ']; %#ok<AGROW>
                                end
                            end
                            if j ~= cols
                                argString = [argString, '; ']; %#ok<AGROW>
                            end
                        end
                    else
                        argString = num2str(inputArg);
                    end
                case 'char'
                    startChar = '''';
                    endString = startChar;
                    argString = inputArg;
                case 'cell'
                    startString = '{';
                    endString = '}';
                    for j = 1:numel(inputArg)
                        argString = [argString, ...
                            publicsim.models.QsubModel.argToString(inputArg{j})]; %#ok<AGROW>
                        if j ~= numel(inputArg)
                            argString = [argString, ', ']; %#ok<AGROW>
                        end
                    end
                otherwise
                    argString = sprintf('Class: %s', detail.class);
            end
            outString = [startString, argString, endString];
        end
        
        function logRun(runId, functionName, varargin)
            runfileDir = 'rundata';
            if ~exist(runfileDir, 'dir')
                mkdir(runfileDir);
            end
            
            logFile = [runfileDir, filesep(), 'QsubCreationLog.txt'];
            fid = fopen(logFile, 'a');
            logString = sprintf('Run ID: %04d, Function: %s, Arguments: ', ...
                runId, functionName);
            
            for i = 1:numel(varargin)
                if i ~= 1
                    logString = [logString, ', ']; %#ok<AGROW>
                end
                logString = [logString, ...
                    publicsim.models.QsubModel.argToString(varargin{i})]; %#ok<AGROW>
            end
            fprintf(fid, [datestr(datetime), ': ', logString, '\n']);
            fclose(fid);
        end
            
    end
    
end

