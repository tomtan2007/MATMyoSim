function result = mava_reduced_report(out_dir, recovery_alpha)
% Consolidate reduced multistarts and test acute-to-baseline 24 h recovery.

if nargin < 1 || isempty(out_dir)
    out_dir = fullfile(fileparts(mfilename('fullpath')), ...
        'output', 'reduced_multistart');
end
if nargin < 2 || isempty(recovery_alpha)
    recovery_alpha = linspace(0,1,11);
end
script_dir = fileparts(mfilename('fullpath'));
fitting_dir = fileparts(script_dir);
repo_root = fullfile(script_dir, '..', '..', '..');
addpath(genpath(repo_root));
addpath(genpath(fullfile(repo_root,'Code','System')));

files = dir(fullfile(out_dir,'*_s*_optimization.json'));
runs = table;
for i = 1:numel(files)
    token = regexp(files(i).name, ...
        '^(ctrl|hcm)_acute_r(10|20)_s(\d+)_optimization\.json$', ...
        'tokens','once');
    if isempty(token), continue; end
    genotype_code = token{1}; ratio = str2double(token{2});
    restart = str2double(token{3});
    if strcmp(genotype_code,'ctrl')
        genotype = "Control"; demo = 'twitch_6state_control'; target_id = 'ctrl_acute';
    else
        genotype = "H251N"; demo = 'twitch_6state_HCM'; target_id = 'hcm_acute';
    end
    run_id = sprintf('%s_acute_r%d_s%02d',genotype_code,ratio,restart);
    result_dir = fullfile(out_dir,'results',run_id);
    required = {fullfile(result_dir,'model_best.json'), ...
        fullfile(result_dir,'fit_results.json'), ...
        fullfile(result_dir,'best_optimization.json')};
    if ~all(cellfun(@isfile,required)), continue; end

    model = loadjson(required{1});
    fit = loadjson(required{2});
    best_opt = loadjson(required{3});
    p = model.MyoSim_model.hs_props.parameters;
    base = loadjson(fullfile(fitting_dir,demo,'temp','best','model_best.json'));
    p0 = base.MyoSim_model.hs_props.parameters;
    protocol_file = fullfile(out_dir,'data',[target_id '_protocol.txt']);
    target_file = fullfile(out_dir,'data',[target_id '_target.txt']);
    options_file = fullfile(fitting_dir,demo,'sim_input','sim_options.json');
    protocol = readtable(protocol_file,'FileType','text','Delimiter','\t');
    t = cumsum(protocol.dt)-protocol.dt(1);
    onset = find(protocol.pCa<6.70,1,'first');
    target = load(target_file);
    tm = mava_waveform_metrics(t,target,onset,'prezeroed');
    sim = simulation_driver('model_json_file_string',required{1}, ...
        'simulation_protocol_file_string',protocol_file, ...
        'options_json_file_string',options_file);
    mm = mava_waveform_metrics(t,sim.muscle_force,onset,'model');
    [boundary_count,boundary_parameters] = boundary_status( ...
        best_opt.MyoSim_optimization.parameter);
    peak_error = (mm.peak-tm.peak)/tm.peak;
    tpeak_error = (mm.time_to_peak_centroid-tm.time_to_peak_centroid) / ...
        tm.time_to_peak_centroid;
    relax_error = (mm.relax_half_time-tm.relax_half_time)/tm.relax_half_time;
    total_score = peak_error^2+tpeak_error^2+relax_error^2;
    srx_rest = sim.M1(onset-1,1)+sim.M6(onset-1,1);
    srx_peak = sim.M1(mm.peak_index,1)+sim.M6(mm.peak_index,1);

    row = table(string(run_id),genotype,ratio,restart,fit.best_error,fit.aic, ...
        boundary_count,string(boundary_parameters),p.k_1,p.k_2,p.k_3, ...
        p.k_5_0,p.k_4_0,p.k_7_3,p.k_1/p0.k_1,p.k_3/p0.k_3, ...
        p.k_5_0/p0.k_5_0,p.k_4_0/p0.k_4_0,p.k_7_3/p0.k_7_3, ...
        mm.peak,mm.time_to_peak_centroid,mm.relax_half_time, ...
        peak_error,tpeak_error,relax_error,total_score,srx_rest,srx_peak, ...
        'VariableNames',{'run_id','genotype','ratio','restart','best_error', ...
        'aic','boundary_count','boundary_parameters','k_1','k_2','k_3', ...
        'k_5_0','k_4_0','k_7_3','k_1_fold','k_3_fold','k_5_0_fold', ...
        'k_4_0_fold','k_7_3_fold','peak','time_to_peak','relax_half_time', ...
        'peak_error','tpeak_error','relax_error','total_score', ...
        'srx_rest','srx_peak'});
    runs = [runs;row]; %#ok<AGROW>
end
runs = sortrows(runs,{'genotype','ratio','restart'});
writetable(runs,fullfile(out_dir,'reduced_run_summary.csv'));

groups = table;
keys = unique(runs(:,{'genotype','ratio'}),'rows');
for i = 1:height(keys)
    D = runs(runs.genotype==keys.genotype(i) & runs.ratio==keys.ratio(i),:);
    [~,b] = min(D.best_error);
    groups = [groups;table(keys.genotype(i),keys.ratio(i),height(D), ...
        min(D.best_error),median(D.best_error),max(D.best_error), ...
        nnz(D.boundary_count>0),D.run_id(b),D.total_score(b), ...
        max(D.k_1_fold)/min(D.k_1_fold),max(D.k_3_fold)/min(D.k_3_fold), ...
        max(D.k_5_0_fold)/min(D.k_5_0_fold), ...
        max(D.k_4_0_fold)/min(D.k_4_0_fold), ...
        max(D.k_7_3_fold)/min(D.k_7_3_fold), ...
        'VariableNames',{'genotype','ratio','n_starts','min_fit_error', ...
        'median_fit_error','max_fit_error','boundary_runs','best_run_id', ...
        'best_metric_score','k_1_spread','k_3_spread','k_5_0_spread', ...
        'k_4_0_spread','k_7_3_spread'})]; %#ok<AGROW>
end
writetable(groups,fullfile(out_dir,'reduced_group_summary.csv'));

recovery = recovery_scan(groups,runs,out_dir,fitting_dir,recovery_alpha);
writetable(recovery,fullfile(out_dir,'recovery_path_summary.csv'));
if numel(recovery_alpha)>2
    plot_report(runs,groups,recovery,out_dir);
end
result.runs = runs; result.groups = groups; result.recovery = recovery;
end

function recovery = recovery_scan(groups,runs,out_dir,fitting_dir,alphas)
names = {'k_1','k_3','k_5_0','k_4_0','k_7_3'};
recovery = table;
for i = 1:height(groups)
    G = groups(i,:);
    best = runs(runs.run_id==G.best_run_id,:);
    if G.genotype=="Control"
        demo='twitch_6state_control'; id='ctrl_24h';
    else
        demo='twitch_6state_HCM'; id='hcm_24h';
    end
    acute_file=fullfile(out_dir,'results',char(G.best_run_id),'model_best.json');
    acute=loadjson(acute_file);
    base=loadjson(fullfile(fitting_dir,demo,'temp','best','model_best.json'));
    pa=acute.MyoSim_model.hs_props.parameters;
    p0=base.MyoSim_model.hs_props.parameters;
    protocol_file=fullfile(out_dir,'data',[id '_protocol.txt']);
    target=load(fullfile(out_dir,'data',[id '_target.txt']));
    protocol=readtable(protocol_file,'FileType','text','Delimiter','\t');
    t=cumsum(protocol.dt)-protocol.dt(1);
    onset=find(protocol.pCa<6.70,1,'first');
    tm=mava_waveform_metrics(t,target,onset,'prezeroed');
    options_file=fullfile(fitting_dir,demo,'sim_input','sim_options.json');
    tmp_file=fullfile(out_dir,sprintf('recovery_%s_r%d.json', ...
        lower(char(G.genotype)),G.ratio));
    for a=alphas
        model=base; p=p0;
        for q=1:numel(names)
            name=names{q};
            p.(name)=10^((1-a)*log10(p0.(name))+a*log10(pa.(name)));
        end
        p.k_2=G.ratio*p.k_1;
        model.MyoSim_model.hs_props.parameters=p;
        write_model(model,tmp_file);
        sim=simulation_driver('model_json_file_string',tmp_file, ...
            'simulation_protocol_file_string',protocol_file, ...
            'options_json_file_string',options_file);
        mm=mava_waveform_metrics(t,sim.muscle_force,onset,'model');
        pe=(mm.peak-tm.peak)/tm.peak;
        te=(mm.time_to_peak_centroid-tm.time_to_peak_centroid)/tm.time_to_peak_centroid;
        re=(mm.relax_half_time-tm.relax_half_time)/tm.relax_half_time;
        score=pe^2+te^2+re^2;
        recovery=[recovery;table(G.genotype,G.ratio,G.best_run_id,a, ...
            mm.peak,mm.time_to_peak_centroid,mm.relax_half_time, ...
            tm.peak,tm.time_to_peak_centroid,tm.relax_half_time, ...
            pe,te,re,score, ...
            'VariableNames',{'genotype','ratio','acute_run_id','acute_fraction', ...
            'peak','time_to_peak','relax_half_time','target_peak', ...
            'target_time_to_peak','target_relax_half_time','peak_error', ...
            'tpeak_error','relax_error','total_score'})]; %#ok<AGROW>
    end
end
end

function [count,names] = boundary_status(parameters)
hits=strings(0);
for i=1:numel(parameters)
    p=parameters{i}.p_value;
    if p<=0.02, hits(end+1)=string(parameters{i}.name)+" low"; %#ok<AGROW>
    elseif p>=0.98, hits(end+1)=string(parameters{i}.name)+" high"; %#ok<AGROW>
    end
end
count=numel(hits);
if count==0, names="none"; else, names=strjoin(hits,'; '); end
end

function plot_report(runs,groups,recovery,out_dir)
fig=figure('Visible','off','Color','w','Position',[40 40 1100 760]);
for g=1:2
    genotype=["Control","H251N"]; ax=subplot(2,1,g); hold(ax,'on');
    for ratio=[10 20]
        D=runs(runs.genotype==genotype(g)&runs.ratio==ratio,:);
        scatter(ax,repmat(ratio,height(D),1),D.best_error,55,D.boundary_count, ...
            'filled','jitter','on','jitterAmount',0.8);
    end
    title(ax,genotype(g)); ylabel(ax,'waveform fit error'); xticks(ax,[10 20]);
    xlabel(ax,'k_2/k_1 ratio'); grid(ax,'on'); box(ax,'off');
end
sgtitle('Reduced five-parameter multistart fits (color = boundary count)');
saveas(fig,fullfile(out_dir,'reduced_multistart_audit.png')); close(fig);

fig=figure('Visible','off','Color','w','Position',[40 40 1000 650]); hold on;
styles={'-','--','-.',':'};
for i=1:height(groups)
    D=recovery(recovery.genotype==groups.genotype(i)& ...
        recovery.ratio==groups.ratio(i),:);
    plot(D.acute_fraction,D.total_score,styles{i},'LineWidth',2, ...
        'DisplayName',sprintf('%s, %dx',groups.genotype(i),groups.ratio(i)));
end
xlabel('acute-fit parameter fraction (0 = baseline, 1 = acute)');
ylabel('24 h amplitude/timing score'); grid on; box off; legend('Location','best');
title('Can kinetic reversal explain 24 h recovery?');
saveas(fig,fullfile(out_dir,'recovery_path.png')); close(fig);
end

function write_model(model,file)
fid=fopen(file,'w'); if fid<0,error('Could not write %s.',file);end
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',savejson('MyoSim_model',model.MyoSim_model));
end
